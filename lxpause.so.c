#include "o/pause.glade.ch"
#include "pause-common.h"
#include "config.h"

#include <lxpanel/plugin.h>
#include <stdlib.h>

static void init(void) {
	exit(97);
	configInit();
}

static GtkWidget* new_instance(LXPanel* panel, config_setting_t *settings) {
//	GtkWidget *p = gtk_event_box_new();
//	gtk_widget_set_has_window(p, FALSE);
	
	struct pause_toggle_state* pts = g_new(struct pause_toggle_state,1);

	GtkBuilder* builder = gtk_builder_new();
	gtk_builder_add_from_string(builder,(gchar*)gladeFile,gladeFile_length,NULL);
	GtkObject* o = gtk_builder_get_object(builder,"image");
	assert(o != NULL);
	pts->image = GTK_IMAGE(o);
	g_object_unref(builder);
	pts->paused = FALSE;
	GtkWidget* p = gtk_event_box_new();
	g_signal_connect(p,"button-release-event",G_CALLBACK(pause_toggle), pts);
	gtk_container_add(GTK_CONTAINER(p),GTK_WIDGET(pts->image));
	return p;
}

FM_DEFINE_MODULE(lxpanel_gtk, pauser);

LXPanelPluginInit fm_module_init_lxpanel_gtk = {
	.new_instance = new_instance,
	.name = "Pause Player",
	.description = "Pause the currently running song player.",
};
