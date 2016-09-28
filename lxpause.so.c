#include <lxpanel/plugin.h>
#include "o/pause.glade.ch"
#include "pause-common.h"
#include "config.h"



static void init(void) {
	configInit();
}

static GtkWidget* new_instance(LXPanel* panel, config_setting_t *settings) {
//	GtkWidget *p = gtk_event_box_new();
//	gtk_widget_set_has_window(p, FALSE);
	
	struct pause_toggle_state* pts = g_new(struct pause_toggle_state,1);

	GtkBuilder* builder = gtk_builder_new_from_string((gchar*)gladeFile,gladeFile_length);
	pts->image = GTK_IMAGE(gtk_builder_get_object(builder,"image"));
	g_object_unref(builder);
	pts->paused = FALSE;
	g_signal_connect(pts->image,"button-release-event",G_CALLBACK(pause_toggle), pts);
	return GTK_WIDGET(pts->image);
}

FM_DEFINE_MODULE(lxpanel_gtk, pauser);

LXPanelPluginInit fm_module_init_lxpanel_gtk = {
	.new_instance = new_instance,
	.init = init,
	.name = "Pause Player",
	.description = "Pause the currently running song player.",
};
