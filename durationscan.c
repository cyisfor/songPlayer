#include "urlcodec.h"

#include <stdio.h>
#include <stdlib.h>
#include <gst/gst.h>
#include <string.h>

GMainLoop *loop = NULL;

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

GstElement* pipe = NULL;

gboolean justOne = FALSE;

static gboolean
bus_call (GstBus     *bus,
          GstMessage *msg,
          gpointer    data)
{
    {
      //g_print("Um %x %x\n",GST_MESSAGE_TYPE(msg),GST_MESSAGE_STREAM_STATUS);
      GstFormat fmt = GST_FORMAT_TIME;
      guint64 len = -1;
      if(gst_element_query_duration (pipe, &fmt, &len)) {
        g_print ("(duration #x%lx)\n", len);
        fflush(stdout);
        if(justOne==TRUE)
          g_main_loop_quit(loop);
        else
          gst_element_set_state (pipe, GST_STATE_NULL);
      } 
    }

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

  case GST_MESSAGE_STREAM_STATUS:
    break;
  
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
GstElement* decoder = NULL;
static void nextSong(GString* next) {
  gst_element_set_state (pipe, GST_STATE_NULL);
  struct stat buf;
  if(stat(next->str,&buf)!=0) {
    g_print("(error file-not-found \"%s\")\n",next->str);
  } else {
    g_object_set (src, "location", next->str, NULL);
    gst_element_set_state (pipe, GST_STATE_PLAYING);
  }
}

static gboolean on_input(GIOChannel* in, GIOCondition condition, void* whatever) {
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


static void watch_input(void) {
  GIOChannel* in = g_io_channel_unix_new(0);
  g_io_add_watch(in,G_IO_IN,(void*)on_input,loop);
}

int
main (int argc, char ** argv)
{
  gst_init (&argc, &argv);

  loop = g_main_loop_new (NULL, FALSE);

  pipe = gst_pipeline_new ("pipeline");

  src = gst_element_factory_make ("filesrc", NULL);

  // this duration derp
  decoder = gst_element_factory_make("decodebin2",NULL);
  //GstElement* converter = gst_element_factory_make("audioconvert",NULL);

  GstElement* alsa = gst_element_factory_make("fakesink", NULL);

  if(!(src && decoder && alsa))
    g_error("_______ could not be created");


  GstBus* bus = gst_pipeline_get_bus (GST_PIPELINE (pipe));
  gst_bus_add_watch (bus, bus_call, loop);
  g_object_unref(bus);

  gst_bin_add_many (GST_BIN (pipe), src, decoder, 
                    alsa, NULL);

  // src -> decoder ...> converter -> analyzer -> sink
  gst_element_link(src,decoder);
  g_signal_connect (decoder, "pad-added", G_CALLBACK (on_new_pad), alsa);

  if(argc==2) {
    GString* next = g_string_new(argv[1]);
    justOne = 1;
    nextSong(next);    
  } else {
    watch_input();
  }

  g_main_loop_run(loop);
  gst_element_set_state (pipe, GST_STATE_NULL);
  gst_object_unref (pipe);
  return 0;
}
