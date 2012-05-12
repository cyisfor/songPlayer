#include "select.h"
#include "urlcodec.h"
#include "config.h"
#include "pq.h"
#include "preparation.h"

#include <fcntl.h> // open O_RDONLY
#include <unistd.h> // STDIN_FILENO

#include <stdio.h>
#include <stdlib.h>
#include <gst/gst.h>
#include <string.h>
#include <stdint.h>

#include <assert.h>

static gchar* strescape(const gchar* unformatted, 
			const gchar* targets, 
			const gchar* substs) {
  ssize_t uflen = strlen(unformatted);
  ssize_t tlen = strlen(targets);
  GString* results = g_string_sized_new(uflen);
  int i;
  for(i=0;i<uflen;++i) {
    int j;
    gboolean found = FALSE;
    for(j=0;j<tlen;++j) {
      if(unformatted[i]==targets[j]) {
	g_string_append_c(results,'\\');
	g_string_append_c(results,substs[j]);
	found = TRUE;
	break;
      }
    }
    if(found==FALSE) 
      g_string_append_c(results,unformatted[i]);
  }
  
  return g_string_free(results,FALSE);
}

FILE* tagHack = NULL;

static void
print_one_tag (const GstTagList * list, const gchar * tag, gpointer user_data)
{
  int i, num;

  num = gst_tag_list_get_tag_size (list, tag);
  for (i = 0; i < num; ++i) {
    const GValue *val;

    /* Note: when looking for specific tags, use the g_tag_list_get_xyz() API,
     * we only use the GValue approach here because it is more generic */
    val = gst_tag_list_get_value_index (list, tag, i);
    if (G_VALUE_HOLDS_STRING (val)) {
      const char* unformatted = g_value_get_string (val);
      gchar* formatted = strescape(unformatted,"\"","\"");
      fprintf (tagHack,"(%s . \"%s\")\n", tag, formatted);
      g_free(formatted);
    } else if (G_VALUE_HOLDS_UINT (val)) {
	  unsigned int uint = g_value_get_uint (val);
          fprintf(tagHack,"(%s . #x%x)\n", tag, uint);
    } else if (G_VALUE_HOLDS_DOUBLE (val)) {
      fprintf(tagHack, "(%s . %g)\n", tag, g_value_get_double (val));
    } else if (G_VALUE_HOLDS_BOOLEAN (val)) {
      fprintf(tagHack,"(%s . %s)\n", tag,
          (g_value_get_boolean (val)) ? "#t" : "#f");
    } else if (GST_VALUE_HOLDS_BUFFER (val)) {
      fprintf(tagHack, "(%s . (buffer %u))", tag,
          GST_BUFFER_SIZE (gst_value_get_buffer (val)));
    } else if (GST_VALUE_HOLDS_DATE (val)) {
	   GDate* date = (GDate*)gst_value_get_date(val);
           fprintf(tagHack, "(%s . (date 0 0 0 %u %u %u))\n", tag,
	  	g_date_get_day(date),
		g_date_get_month(date),
        g_date_get_year (date));
    } else {
      fprintf(tagHack, "(%20s . (type %s))", tag, G_VALUE_TYPE_NAME (val));
    }
  }
}

static gboolean
bus_call (GstBus     *bus,
          GstMessage *msg,
          gpointer    data)
{
  GMainLoop *loop = (GMainLoop *) data;

  switch (GST_MESSAGE_TYPE (msg)) {
  case GST_MESSAGE_EOS:
    fclose(tagHack);
    tagHack = NULL;
    write(STDOUT_FILENO,".",1);
    selectDone();
    break;
    
  case GST_MESSAGE_ERROR: {
    gchar  *debug;
    GError *error;
    
    gst_message_parse_error (msg, &error, &debug);
    g_free (debug);
    
    g_printerr ("Error: %s\n", error->message);
    g_error_free (error);
    
    g_main_loop_quit (loop);
    break;
  }
    
  case GST_MESSAGE_TAG: {
    GstTagList *tags = NULL;
    if(tagHack==NULL) {
      const char* it = configAt("tags");
      tagHack = fopen(it,"wt");
    }
    gst_message_parse_tag (msg, &tags);
    gst_tag_list_foreach(tags,print_one_tag,NULL);
    gst_tag_list_free(tags);
    break;
  }
    
  default:
    break;
  };

  return TRUE;
}

static void
on_new_pad (GstElement * dec, GstPad * pad, GstElement * sinkElement)
{
  GstPad *sinkpad;
  if(pad==NULL) return;
  if(sinkElement==NULL) return;

  sinkpad = gst_element_get_static_pad (sinkElement, "sink");
  if(sinkpad==NULL) return;
  if (!gst_pad_is_linked (sinkpad)) {
    GstPadLinkReturn ret = gst_pad_link (pad, sinkpad);
    if(ret == GST_PAD_LINK_NOFORMAT) {
      GstCaps* a, *b;
      a = gst_pad_get_caps(pad);
      b = gst_pad_get_caps(sinkpad);
      g_warning("Formats of A: %s\nFormats of B:%s\n",
	      a ? gst_caps_to_string(a) : "<NULL>",
	      b ? gst_caps_to_string(b) : "<NULL>");
      gst_pad_unlink (pad, sinkpad);
    } else if(ret != GST_PAD_LINK_OK) {
      g_error("beep");
      GstElement* parentA = gst_pad_get_parent_element(pad);
      GstElement* parentB = gst_pad_get_parent_element(sinkpad);
      g_error ("Failed to link pads! %s - %s : %d",
	       gst_element_get_name(parentA),
	       gst_element_get_name(parentB),
	       ret);
      g_object_unref(parentA);
      g_object_unref(parentB);
      exit(3);
    }				    
  }
  gst_object_unref (sinkpad);
}

GstElement* src = NULL;
GstElement* pipeline = NULL;
GstBus* bus = NULL;

static int nextSong(const char* next) {
  gst_element_set_state (pipeline, GST_STATE_NULL);
  struct stat buf;
  if(stat(next,&buf)!=0) {
    write(STDOUT_FILENO,"!",1);
    exit(1);
  } else {
    g_object_set (src, "location", next, NULL);
    gst_element_set_state (pipeline, GST_STATE_PLAYING);
    return 0;
  }
}

const char* query = NULL;

struct {
  gdouble gain;
  gdouble peak;
  gdouble level;
  gboolean (*super) (GstPad *pad,
                     gboolean active);
} g_activate_gain = { 0, 0, 0, NULL };

gboolean on_activate(GstPad* pad, gboolean active) {
  gboolean ret = FALSE;
  if(g_activate_gain.super)
    ret = g_activate_gain.super(pad,active);

  if(active==FALSE) return ret;
  
  GstTagList* list = gst_tag_list_new();
  GValue value;
  memset(&value,0,sizeof(value));
  g_value_init(&value,G_TYPE_DOUBLE);
  fprintf(stderr,"bwub setting gain/peak %f %f %f\n",
          g_activate_gain.peak, g_activate_gain.gain,
          g_activate_gain.level);

  g_value_set_double(&value,g_activate_gain.gain);
  gst_tag_list_add_value(list, GST_TAG_MERGE_REPLACE, GST_TAG_TRACK_GAIN, &value);
  g_value_set_double(&value,g_activate_gain.peak);
  gst_tag_list_add_value(list,  GST_TAG_MERGE_REPLACE, GST_TAG_TRACK_PEAK, &value);
  g_value_set_double(&value,g_activate_gain.level);
  gst_tag_list_add_value(list,  GST_TAG_MERGE_REPLACE, GST_TAG_REFERENCE_LEVEL, &value);
  assert(TRUE==gst_pad_send_event(pad,gst_event_new_tag(list)));
  return ret;
}   

/* Note: will restart the current song if called. */

void playerPlay(void) {
  uint32_t lastId = -1;
  PGresult* result = 
    PQexecPrepared(PQconn,"getTopRecording",
                   0,NULL,NULL,NULL,0);
  int rows = PQntuples(result);
  int cols = PQnfields(result);
  fprintf(stderr,"rows %x cols %x\n",rows,cols);
  PQassert(result,rows>=1 && cols==1);
  char* end;

  char* recording = PQgetvalue(result,0,0);
  uint32_t id = strtol(recording,&end,10);
  fprintf(stderr,"ID %x %x\n",id,lastId);
  if (id==lastId) {
    fprintf(stderr,"(error repeated-song #x%x)\n",id);
    goto CLEAR;
  } else {
    lastId = id;
  }

  uint16_t len = strlen(recording);
  int fmt = 0;
  
  rows = PQntuples(result);
  cols = PQnfields(result);
  PQassert(result,rows==1 && cols==5);
  g_activate_gain.gain = g_ascii_strtod(PQgetvalue(result,0,1),&end);
  g_activate_gain.peak = g_ascii_strtod(PQgetvalue(result,0,2),&end);
  g_activate_gain.level = g_ascii_strtod(PQgetvalue(result,0,3),&end);
  nextSong(PQgetvalue(result,0,4));  
  PQclear(result);
}

static gboolean on_input (GIOChannel *source,
                   GIOCondition condition,
                   gpointer data) {
  gchar buf[0x100];
  GError* error = NULL;
  gsize amt;
  for(;;) {
    GIOStatus status =  g_io_channel_read_chars (source,
                                                 buf,
                                                 0x100,
                                                 &amt,
                                                 &error);
    switch(status) {
    case G_IO_STATUS_NORMAL:
      continue;
    case G_IO_STATUS_AGAIN:
      break;
    case G_IO_STATUS_EOF:
      g_main_loop_quit (loop);
      return;
    case G_IO_STATUS_ERROR:
      g_printerr(error->message);
      exit(error->code);
    };
  }
  selectNext();
}

void watchInput(void) {
  GIOChannel* in = g_io_channel_unix_new(STDIN_FILENO);
  g_io_add_watch(in,G_IO_IN,(void*)on_input,loop);
}

int
main (int argc, char ** argv)
{
  gst_init (NULL,NULL);
  configInit();
  PQinit();

  preparation_t queries = {
    { "getTopRecording",
      "SELECT recording FROM queue ORDER BY id LIMIT 1" }
  };
  prepareQueries(queries);

  GMainLoop* loop = g_main_loop_new (NULL, FALSE);

  pipeline = gst_pipeline_new ("pipeline");

  src = gst_element_factory_make ("filesrc", NULL);

  // this parses the FLAC tags to replay gain stuff.
  GstElement* decoder = gst_element_factory_make("decodebin2",NULL);
  GstElement* converter = NULL;
  GstElement* adjuster = NULL;
  if(!getenv("noreplaygain")) {
    converter = gst_element_factory_make("audioconvert",NULL);
    adjuster = gst_element_factory_make("rgvolume", NULL);
    GstPad* rgsource = gst_element_get_static_pad (adjuster, "sink");
    assert(rgsource != NULL);
    // XXX: meh! this also needs to only on_activate when the 
    // FLUSH_STOP event comes around. Have to wrap the event
    // handler too?
    g_activate_gain.super = rgsource->activatepushfunc;
    gst_pad_set_activatepush_function(rgsource,on_activate);
    if(!(adjuster && converter)) 
      g_error("Adjuster could not be created");
    g_object_set (adjuster, "album-mode", FALSE, NULL);
    g_object_set (adjuster, "pre-amp", 6.0, NULL);
    g_object_set (adjuster, "headroom", 0.0, NULL);
  }

  GstElement* alsa = gst_element_factory_make("alsasink", NULL);

  if(!(src && decoder && alsa)) 
  	g_error("One element could not be created...");

  bus = gst_pipeline_get_bus (GST_PIPELINE (pipeline));
  gst_bus_add_watch (bus, bus_call, loop);

  if(adjuster)
    gst_bin_add_many (GST_BIN (pipeline), src, decoder, 
		      converter, adjuster, 
		      alsa, NULL);
  else
    gst_bin_add_many (GST_BIN (pipeline), src, decoder, alsa, NULL);

  gst_element_link(src,decoder);
  if(adjuster) {
    gst_element_link_many(converter, adjuster, alsa, NULL);
    g_signal_connect (decoder, "pad-added", G_CALLBACK (on_new_pad), converter);
  } else {
    g_signal_connect (decoder, "pad-added", G_CALLBACK (on_new_pad), alsa);
  }

  watchInput(loop);  

  selectSetup();

  playerPlay();

  g_main_loop_run(loop);
  gst_element_set_state (pipeline, GST_STATE_NULL);
  puts("shutting down");
  gst_object_unref (pipeline);
  return 0;
}
