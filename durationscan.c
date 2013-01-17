#include "urlcodec.h"
#include "pq.h"
#include "preparation.h"

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

GstElement* panpipe = NULL;

gint64 lastDuration = -1;

static gboolean
bus_call (GstBus     *bus,
          GstMessage *msg,
          gpointer    data)
{
    {
      GstFormat fmt = GST_FORMAT_TIME;
      guint64 len = -1;
      if(gst_element_query_duration (panpipe, &fmt, &len)) {
        lastDuration = len;
        gst_element_set_state (panpipe, GST_STATE_NULL);
        g_main_loop_quit(loop);
      }
    }

  switch (GST_MESSAGE_TYPE (msg)) {
  case GST_MESSAGE_EOS:
    g_print ("end-of-stream\n");
    g_main_loop_quit(loop);
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
static short nextSong(const char* path) {
  gst_element_set_state (panpipe, GST_STATE_NULL);
  struct stat buf;
  if(stat(path,&buf)!=0) {
    return 1;
  } else {
    g_object_set (src, "location", path, NULL);
    gst_element_set_state (panpipe, GST_STATE_PLAYING);
    return 0;
  }
}

int
main (int argc, char ** argv)
{
    PQinit();
    preparation_t queries[] = {
        { "nullRecordings",
          "SELECT id,path FROM recordings WHERE duration IS NULL"},
        { "deleteRecording",
            "DELETE FROM recordings WHERE id = $1"},
        { "setDuration",
            "UPDATE recordings SET duration = $2 WHERE id = $1"}
    };
    prepareQueries(queries);
    PGresult* recordings = PQexecPrepared(PQconn,"nullRecordings",
            0,NULL,NULL,NULL,0);


  gst_init (&argc, &argv);

  loop = g_main_loop_new (NULL, FALSE);

  panpipe = gst_pipeline_new ("pipeline");

  src = gst_element_factory_make ("filesrc", NULL);

  // this duration derp
  decoder = gst_element_factory_make("decodebin2",NULL);
  //GstElement* converter = gst_element_factory_make("audioconvert",NULL);

  GstElement* alsa = gst_element_factory_make("fakesink", NULL);

  if(!(src && decoder && alsa))
    g_error("_______ could not be created");


  GstBus* bus = gst_pipeline_get_bus (GST_PIPELINE (panpipe));
  gst_bus_add_watch (bus, bus_call, loop);
  g_object_unref(bus);

  gst_bin_add_many (GST_BIN (panpipe), src, decoder,
                    alsa, NULL);

  // src -> decoder ...> converter -> analyzer -> sink
  gst_element_link(src,decoder);
  g_signal_connect (decoder, "pad-added", G_CALLBACK (on_new_pad), alsa);

    int i;
    for(i=0;i<PQntuples(recordings);++i) {
        GString* next = g_string_new(argv[1]);
        const char* values[2] = { PQgetvalue(recordings,i,0) };
        int lengths[2] = { PQgetlength(recordings,i,0) };
        int fmt[] = { 0, 0 };

        if(0!=nextSong(PQgetvalue(recordings,i,1))) {
            PQcheckClear(PQexecPrepared(PQconn,"deleteRecording",
                        1,values,lengths,fmt,0));
        } else {
            g_main_loop_run(loop);
            if(lastDuration>0) {
                char stdurr[0x100];
                lengths[1] = snprintf(stdurr,0x100,"%lu",lastDuration);
                values[1] = stdurr;
                PQcheckClear(PQexecPrepared(PQconn,"setDuration",
                        2,values,lengths,fmt,0));
                lastDuration = -1;
            }
        }
    }

    exit(0);
}
