#include "urlcodec.h"
#include "pq.h"
#include "preparation.h"

#include <stdio.h>
#include <stdlib.h>
#include <gst/gst.h>
#include <string.h>
#include <sys/stat.h>

preparation nextRGlessRecording = NULL;

char* currentRecording = NULL;

GstElement* src = NULL;
GstElement* derpipe = NULL;
static void nextSong(void) {
	PGresult* next = prepare_exec(nextRGlessRecording,
																0,
																NULL,
																NULL,
																NULL,
																0);
  gst_element_set_state (derpipe, GST_STATE_NULL);
  if(PQntuples(next)==0) {
      puts("All songs are replaygain analyzed.");
      exit(0);
  }
  char* path = PQgetvalue(next,0,0);
  struct stat buf;
  if(stat(path,&buf)!=0) {
      g_print("(error file-not-found \"%s\")\n",path);
      PQclear(next);
  } else {
      g_object_set (src, "location", path, NULL);
      currentRecording = strdup(PQgetvalue(next,0,1));
      g_message("Examining %s %s\n",currentRecording,path);
      PQclear(next);
      gst_element_set_state (derpipe, GST_STATE_PLAYING);
  }
}

struct rginfo {
    double peak;
    double gain;
    double level;
    short numgot;
};

preparation _setReplayGain = NULL;

void setReplayGain(struct rginfo* info) {
    char peak[0x400];
    char gain[0x400];
    char level[0x400];
    guint plen = snprintf(peak,0x400,"%lf",info->peak);
    guint glen = snprintf(gain,0x400,"%lf",info->gain);
    guint llen = snprintf(level,0x400,"%lf",info->level);

    const char* values[] = { currentRecording, peak, gain, level };
    int lengths[] = { strlen(currentRecording), plen, glen, llen };
    int fmt[] = { 0, 0, 0, 0 };
    PQcheckClear(prepare_exec(_setReplayGain,
															4,
															values,
															lengths,
															fmt,
															0));
    free(currentRecording);
    currentRecording = NULL;
    info->numgot = 0;
}


static void
handle_one_tag (const GstTagList * list, const gchar * tag, gpointer user_data)
{
  struct rginfo* info = (struct rginfo*)user_data;
  if(info->numgot == (1|2|4)) return;

  if(0==strcmp(tag,"replaygain-track-peak")) {
      gst_tag_list_get_double_index(list,tag,0,&info->peak);
      info->numgot |= 1;
  } else if(0==strcmp(tag,"replaygain-track-gain")) {
      gst_tag_list_get_double_index(list,tag,0,&info->gain);
      info->numgot |= 2;
  } else if(0==strcmp(tag,"replaygain-reference-level")) {
      gst_tag_list_get_double_index(list,tag,0,&info->level);
      info->numgot |= 4;
  }
}

struct businfo {
    struct rginfo info;
    GMainLoop* loop;
};



static gboolean
bus_call (GstBus     *bus,
          GstMessage *msg,
          gpointer    data)
{
    if(currentRecording==NULL) return TRUE;

    struct businfo* derp = (struct businfo*) data;

  switch (GST_MESSAGE_TYPE (msg)) {
  case GST_MESSAGE_EOS:
    g_print ("end-of-stream\n");
    free(currentRecording);
    currentRecording = NULL;
    nextSong();
    break;

  case GST_MESSAGE_ERROR: {
    gchar  *debug;
    GError *error;

    gst_message_parse_error (msg, &error, &debug);
    g_free (debug);

    g_printerr ("Error: %s\n", error->message);
    g_error_free (error);

    g_main_loop_quit (derp->loop);
    break;
  }

  case GST_MESSAGE_TAG: {
    GstTagList *tags = NULL;
    gst_message_parse_tag (msg, &tags);
    gst_tag_list_foreach(tags,handle_one_tag,&derp->info);
    gst_tag_list_free(tags);
    if(derp->info.numgot==(1|2|4)) {
        setReplayGain(&derp->info);
        nextSong();
        return TRUE;
    }

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

int
main (int argc, char ** argv)
{
	PQinit();
	nextRGlessRecording = prepare
		("SELECT path,recordings.id FROM recordings LEFT OUTER JOIN replaygain ON replaygain.id = recordings.id WHERE replaygain.id IS NULL");
	_setReplayGain = prepare
		("INSERT INTO replaygain (id,peak,gain,level) VALUES ($1,$2,$3,$4)");


  gst_init (&argc, &argv);

  GMainLoop* loop = g_main_loop_new (NULL, FALSE);

  derpipe = gst_pipeline_new ("pipeline");

  src = gst_element_factory_make ("filesrc", NULL);

  // this parses the FLAC tags to replay gain stuff.
  GstElement* decoder = gst_element_factory_make("decodebin",NULL);
  GstElement* converter = gst_element_factory_make("audioconvert",NULL);
  GstElement* analyzer = gst_element_factory_make("rganalysis",NULL);

  GstElement* alsa = gst_element_factory_make("fakesink", NULL);

  if(!(src && decoder && converter && analyzer && alsa))
    g_error("%s could not be created",src ? decoder ? converter ? analyzer ? "alsa" : "analyzer" : "converter" : "decoder" : "src");

  GValue val = { 0, };

  g_value_init (&val, G_TYPE_INT);
  g_value_set_schar (&val, 1);

  g_object_set_property(G_OBJECT(analyzer),"num-tracks",&val);
  g_value_unset(&val);

  GstBus* bus = gst_pipeline_get_bus (GST_PIPELINE (derpipe));
  struct businfo derp = { .loop = loop };
  gst_bus_add_watch (bus, bus_call, &derp);
  g_object_unref(bus);

  gst_bin_add_many (GST_BIN (derpipe), src, decoder,
                    converter, analyzer, alsa, NULL);

  // src -> decoder ...> converter -> analyzer -> sink
  gst_element_link(src,decoder);
  g_signal_connect (decoder, "pad-added", G_CALLBACK (on_new_pad), converter);
  gst_element_link_many(converter, analyzer, alsa, NULL);

  nextSong();

  g_main_loop_run(loop);
  gst_element_set_state (derpipe, GST_STATE_NULL);
  puts("boofff");
  gst_object_unref (derpipe);
  return 0;
}
