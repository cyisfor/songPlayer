#include "urlcodec.h"

#include <stdio.h>
#include <stdlib.h>
#include <gst/gst.h>
#include <string.h>

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
      g_print ("(%s . \"%s\")\n", tag, formatted);
      g_free(formatted);
    } else if (G_VALUE_HOLDS_UINT (val)) {
	  unsigned int uint = g_value_get_uint (val);
	  if(uint > 0xf)
      	g_print ("(%s . #x%x)\n", tag, uint);
    } else if (G_VALUE_HOLDS_DOUBLE (val)) {
      g_print ("(%s . %g)\n", tag, g_value_get_double (val));
    } else if (G_VALUE_HOLDS_BOOLEAN (val)) {
      g_print ("(%s . %s)\n", tag,
          (g_value_get_boolean (val)) ? "#t" : "#f");
    } else if (GST_VALUE_HOLDS_BUFFER (val)) {
      g_print ("(%s . (buffer %u))", tag,
          GST_BUFFER_SIZE (gst_value_get_buffer (val)));
    } else if (GST_VALUE_HOLDS_DATE (val)) {
	   GDate* date = (GDate*)gst_value_get_date(val);
      g_print ("(%s . (date 0 0 0 %u %u %u))\n", tag,
	  	g_date_get_day(date),
		g_date_get_month(date),
        g_date_get_year (date));
    } else {
      g_print ("(%20s . (type %s))", tag, G_VALUE_TYPE_NAME (val));
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
    g_print ("end-of-stream\n");
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
on_new_pad (GstElement * dec, GstPad * pad, GstElement* sinkElement) {
  //g_warning("src %s ...> sink %s",gst_element_name(dec),gst_element_name(sinkElement));
  GstPad *sinkpad;
  if(pad==NULL) return;
  if(sinkElement==NULL) return;

  sinkpad = gst_element_get_static_pad (sinkElement, "sink");
  if(sinkpad==NULL) return;
  if (!gst_pad_is_linked (sinkpad)) {
    GstCaps* a;
    a = gst_pad_get_caps(pad);
    GstCaps* b;
    b = gst_pad_get_caps(sinkpad);
    g_warning("Formats of A: %s\nFormats of B: %s\n",
              a ? gst_caps_to_string(a) : "<NULL>",
              b ? gst_caps_to_string(b) : "<NULL>");

    GstPadLinkReturn ret = gst_pad_link (pad, sinkpad);
    if(ret == GST_PAD_LINK_NOFORMAT) {
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
GstElement* pipe = NULL;
static void nextSong(GString* next) {
  gst_element_set_state (pipe, GST_STATE_NULL);
  struct stat buf;
  if(stat(next->str,&buf)!=0) {
    g_print("(error file-not-found \"%s\")\n",next->str);
  } else {
    g_object_set (src, "location", next->str, NULL);
    GstFormat fmt = GST_FORMAT_TIME;
    gint64 len = -1;
    if(gst_element_query_duration (pipe, &fmt, &len)) {
      g_print ("(duration #x%lx)\n", len);
      fflush(stdout);
    } 
    gst_element_set_state (pipe, GST_STATE_PLAYING);
  }
}

static gboolean on_input(GIOChannel* in, GIOCondition condition, GMainLoop* loop) {
  static GString* buf = NULL;
  if(!buf) {
    buf = g_string_sized_new(0x40);
  }

  GError* error = NULL;

  GIOStatus status = g_io_channel_read_line_string(in,buf,NULL,&error);
  switch(status) {
  case G_IO_STATUS_AGAIN: 
    return TRUE;
  case G_IO_STATUS_EOF:
  case G_IO_STATUS_ERROR: 
    fprintf(stderr,"EEEP\n");
    g_main_loop_quit(loop);
    return FALSE;
  case G_IO_STATUS_NORMAL:
    buf->str[buf->len-1] = '\0';
    nextSong(buf);
    return TRUE;
  };
}


static void watch_input(GMainLoop* loop) {
  GIOChannel* in = g_io_channel_unix_new(0);
  g_io_add_watch(in,G_IO_IN,(void*)on_input,loop);
}

int
main (int argc, char ** argv)
{
  gst_init (&argc, &argv);

  GMainLoop* loop = g_main_loop_new (NULL, FALSE);

  pipe = gst_pipeline_new ("pipeline");

  src = gst_element_factory_make ("filesrc", NULL);

  // this parses the FLAC tags to replay gain stuff.
  GstElement* decoder = gst_element_factory_make("decodebin2",NULL);
  GstElement* converter = gst_element_factory_make("audioconvert",NULL);
  GstElement* analyzer = gst_element_factory_make("rganalysis",NULL);

  GstElement* alsa = gst_element_factory_make("fakesink", NULL);

  if(!(src && decoder && converter && analyzer && alsa))
    g_error("_______ could not be created");

  GValue val = { 0, };

  g_value_init (&val, G_TYPE_INT);
  g_value_set_char (&val, 1);

  g_object_set_property(G_OBJECT(analyzer),"num-tracks",&val);
  g_value_unset(&val);

  GstBus* bus = gst_pipeline_get_bus (GST_PIPELINE (pipe));
  gst_bus_add_watch (bus, bus_call, loop);
  g_object_unref(bus);

  gst_bin_add_many (GST_BIN (pipe), src, decoder, 
                    converter, analyzer, alsa, NULL);

  // src -> decoder ...> converter -> analyzer -> sink
  gst_element_link(src,decoder);
  g_signal_connect (decoder, "pad-added", G_CALLBACK (on_new_pad), converter);
  gst_element_link_many(converter, analyzer, alsa, NULL);

  if(argc==2) {
    GString* next = g_string_new(argv[1]);
    nextSong(next);
  } else {
    watch_input(loop);
  }

  g_main_loop_run(loop);
  gst_element_set_state (pipe, GST_STATE_NULL);
  puts("boofff");
  gst_object_unref (pipe);
  return 0;
}
