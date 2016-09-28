#include "o/pause.glade.ch"
#include "pause-common.h"

#include <lxpanel/plugin.h>

static void init(void) {
	configInit();
}

static GtkWidget* new_instance(LXPanel* panel, config_setting_t *settings) {
//	GtkWidget *p = gtk_event_box_new();
//	gtk_widget_set_has_window(p, FALSE);
	
	GtkBuilder* builder = gtk_builder_new_from_string((gchar*)gladeFile,gladeFile_length);
	image = GTK_IMAGE(gtk_builder_get_object(builder,"image"));
	gtk_builder_destroy(builder);
}

FM_DEFINE_MODULE(lxpanel_gtk, clock);

LXPanelPluginInit fm_module_init_lxpanel_gtk = {
	.new_instance = new_instance,
	.init = init,
	.button_press_event = pause_toggle,
	.name = "Pause Player",
	.description = "Pause the currently running song player.",
};
