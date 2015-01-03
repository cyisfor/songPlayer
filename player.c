#include "select.h"
#include "urlcodec.h"
#include "config.h"
#include "pq.h"
#include "preparation.h"
#include "synchronize.h"
#include "queue.h"
#include "signals.h"

#include <fcntl.h> // open O_RDONLY
#include <unistd.h> // STDIN_FILENO

#include <stdio.h>
#include <stdlib.h>
#include <gst/gst.h>
#include <string.h>
#include <stdint.h>

#include <assert.h>

void playerPlay(void);

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
          gst_buffer_get_size (gst_value_get_buffer (val)));
    } else if (GST_VALUE_HOLDS_DATE_TIME (val)) {
        GstDateTime* date = (GstDateTime*)g_value_get_boxed(val);
        fprintf(tagHack, "(%s . (date 0 0 0 %u %u %u))\n", tag,
	  	gst_date_time_has_day(date) ? gst_date_time_get_day(date) : 0,
		gst_date_time_has_month(date) ? gst_date_time_get_month(date) : 1,
        gst_date_time_has_year(date) ? gst_date_time_get_year (date) : 0);
    } else {
      fprintf(tagHack, "(%20s . (type %s))", tag, G_VALUE_TYPE_NAME (val));
    }
  }
}

const guint error_limit_max = 10; 
const guint error_limit_interval = 1000;
// no more than 10 error messages in 1 second

guint error_limit_amount = 0;
guint error_limit_id = 0;

static gboolean reset_error_limit(gpointer udata) {
    if(error_limit_amount < error_limit_max) {
        error_limit_amount = 0;
        error_limit_id = 0;
        return G_SOURCE_REMOVE;
    } else {
        error_limit_amount -= error_limit_max;
    }
    return G_SOURCE_CONTINUE;
}

GstElement* pipeline = NULL;

static gboolean play_later(gpointer udata) {
    gst_element_set_state (pipeline, GST_STATE_NULL);
    return G_SOURCE_REMOVE;
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
    playerPlay();
    break;

  case GST_MESSAGE_ERROR: {
    gchar  *debug;
    GError *error;

    gst_message_parse_error (msg, &error, &debug);

    g_printerr ("\nError: %s\n%s\n---------------\n", error->message, debug);
    if(0==strcmp(error->message, "Could not open audio device for playback.")) {
        kill(getpid(),SIGTSTP); // for gdb
        g_timeout_add(1000,play_later,NULL);
    }

    if(++error_limit_amount > error_limit_max) {
        g_main_loop_quit(loop);
    } else {
        if(error_limit_id == 0) {
            error_limit_id = g_timeout_add(error_limit_interval,reset_error_limit,NULL);
        }
    }
    g_free (debug);
    g_error_free (error);
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
    fflush(tagHack);
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
      a = gst_pad_get_current_caps(pad);
      b = gst_pad_get_current_caps(sinkpad);
      g_warning("Formats of A: %s\nFormats of B:%s\n",
	      a ? gst_caps_to_string(a) : "<NULL>",
	      b ? gst_caps_to_string(b) : "<NULL>");
      gst_pad_unlink (pad, sinkpad);
    } else if(ret != GST_PAD_LINK_OK) {
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
GstBus* bus = NULL;

static int nextSong(const char* next) {
  fprintf(stderr,"PATH: %s",next);
  gst_element_set_state (pipeline, GST_STATE_NULL);
  struct stat buf;
  if(stat(next,&buf)!=0) {
    write(STDOUT_FILENO,"!",1);
    selectNext();
    playerPlay();
    return 1;
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

static gboolean on_activate(GstPad* pad, GstObject* parent) {
  gst_pad_activate_mode(pad,GST_PAD_MODE_PUSH,TRUE);

  GstTagList* list = gst_tag_list_new_empty();
  GValue value;
  memset(&value,0,sizeof(value));
  g_value_init(&value,G_TYPE_DOUBLE);
  fprintf(stderr,"bwub setting gain/peak %f %f %f\n",
          g_activate_gain.peak, g_activate_gain.gain,
          g_activate_gain.level);
  g_value_set_double(&value,g_activate_gain.gain*2);
  gst_tag_list_add_value(list, GST_TAG_MERGE_REPLACE, GST_TAG_TRACK_GAIN, &value);
  gst_tag_list_add_value(list, GST_TAG_MERGE_REPLACE, GST_TAG_ALBUM_GAIN, &value);
  g_value_set_double(&value,g_activate_gain.peak*2);
  gst_tag_list_add_value(list,  GST_TAG_MERGE_REPLACE, GST_TAG_TRACK_PEAK, &value);
  gst_tag_list_add_value(list,  GST_TAG_MERGE_REPLACE, GST_TAG_ALBUM_PEAK, &value);
  g_value_set_double(&value,g_activate_gain.level);
  gst_tag_list_add_value(list,  GST_TAG_MERGE_REPLACE, GST_TAG_REFERENCE_LEVEL, &value);
  assert(TRUE==gst_pad_send_event(pad,gst_event_new_tag(list)));

  return TRUE;
}

/* Note: will restart the current song if called. */

void playerPlay(void) {
  uint32_t lastId = -1;
  PGresult* result = NULL;
  int rows = 0;

  gst_element_set_state (pipeline, GST_STATE_NULL);

  for(;;) {
      waitUntilSongInQueue();
      result =
          logExecPrepared(PQconn,"getTopRecording",
                         0,NULL,NULL,NULL,0);
      rows = PQntuples(result);
      if(rows>0) break;
      PQclear(result);
      sleep(1);
  }

  int cols = PQnfields(result);
  fprintf(stderr,"rows %x cols %x\n",rows,cols);
  PQassert(result,rows>=1 && cols==5);
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
 CLEAR:
  PQclear(result);
}

static gboolean on_input (GIOChannel *source,
                   GIOCondition condition,
                   gpointer data) {
  gchar buf[0x100];
  GError* error = NULL;
  gsize amt;
  uint8_t ready = 0;
  for(;;) {
    GIOStatus status =  g_io_channel_read_chars (source,
                                                 buf,
                                                 0x100,
                                                 &amt,
                                                 &error);
    if(amt < 0x100) break;
    switch(status) {
    case G_IO_STATUS_NORMAL:
      continue;
    case G_IO_STATUS_AGAIN:
      ready = 1;
      break;
    case G_IO_STATUS_EOF:
      {
        GMainLoop* loop = (GMainLoop*) data;
        g_main_loop_quit (loop);
        return;
      }
    case G_IO_STATUS_ERROR:
      g_printerr("%s",error->message);
      exit(error->code);
    };
    if(ready) break;
  }
  selectNext();
  playerPlay();
  return TRUE;
}

static void watchInput(GMainLoop* loop) {
  GIOChannel* in = g_io_channel_unix_new(STDIN_FILENO);
  GError* error = NULL;
  g_io_channel_set_flags(in,G_IO_FLAG_NONBLOCK,&error);
  if(error) {
    g_error("Can't nonblock %s",error->message);
    exit(23);
  }
  g_io_add_watch(in,G_IO_IN,(void*)on_input,loop);
}

static void signalNext(int signal) {
  // this should execute in the main GTK thread (see signals.c)
  queueInterrupted = 1;
  selectNext();
  playerPlay();
}

static void restartPlayer(int signal) {
  // this should execute in the main GTK thread (see signals.c)
    queueInterrupted = 1;
    playerPlay();
}

int main (int argc, char ** argv)
{
  signalsSetup();
  gst_init (NULL,NULL);
  configInit();
  selectSetup();
  onSignal(SIGUSR1,signalNext);
  onSignal(SIGUSR2,restartPlayer);

  preparation_t queries[] = {
    { "getTopRecording",
      "SELECT queue.recording,"
      "replaygain.gain,replaygain.peak,replaygain.level,"
      "recordings.path "
      "FROM queue INNER JOIN replaygain ON replaygain.id = queue.recording  INNER JOIN recordings ON recordings.id = queue.recording ORDER BY queue.id ASC LIMIT 1" },
    { "setPID",
      "SELECT setPID(0,$1)"}
  };
  prepareQueries(queries);

  {
    char buf[8];
    const char* values[1] = { buf };
    int lengths[1];
    const int fmt[1] = { 0 };
    lengths[0] = snprintf(buf,8,"%d",getpid());
    logExecPrepared(PQconn,"setPID",
                   1,values,lengths,fmt,0);
  }

  GMainLoop* loop = g_main_loop_new (NULL, FALSE);

  pipeline = gst_pipeline_new ("pipeline");

  src = gst_element_factory_make ("filesrc", NULL);

  // this parses the FLAC tags to replay gain stuff.
  GstElement* decoder = gst_element_factory_make("decodebin",NULL);
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
    gst_pad_set_activate_function(rgsource,on_activate);
    if(!(adjuster && converter))
      g_error("Adjuster could not be created");
    g_object_set (adjuster, "album-mode", FALSE, NULL);
    g_object_set (adjuster, "pre-amp", 6.0, NULL);
    g_object_set (adjuster, "headroom", 1.0, NULL);
  }

  GstElement* sink = gst_element_factory_make("alsasink", NULL);

  if(!sink)
    g_error("Sound is disabled or broken god damn doodley");

  /* g_object_set(sink,
          "volume",2.0,
          NULL); */

  if(!src)
      g_error("Source no exist");

  if(!(src && decoder && sink))
  	g_error("One element could not be created...");

  bus = gst_pipeline_get_bus (GST_PIPELINE (pipeline));
  gst_bus_add_watch (bus, bus_call, loop);

  if(adjuster)
    gst_bin_add_many (GST_BIN (pipeline), src, decoder,
		      converter, adjuster,
		      sink, NULL);
  else
    gst_bin_add_many (GST_BIN (pipeline), src, decoder, sink, NULL);

  gst_element_link(src,decoder);
  if(adjuster) {
    gst_element_link_many(converter, adjuster, sink, NULL);
    g_signal_connect (decoder, "pad-added", G_CALLBACK (on_new_pad), converter);
  } else {
    g_signal_connect (decoder, "pad-added", G_CALLBACK (on_new_pad), sink);
  }

  //watchInput(loop);

  playerPlay();

  g_main_loop_run(loop);
  gst_element_set_state (pipeline, GST_STATE_NULL);
  puts("shutting down");
  gst_object_unref (pipeline);
  return 0;
}
