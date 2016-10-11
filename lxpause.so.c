#include "pause-common.h"
#include "config.h"

#include <lxpanel/plugin.h>
#include <stdlib.h>
#include <assert.h>

static void init(void) {
	configInit();
}

static GtkWidget* new_instance(LXPanel* panel, config_setting_t *settings) {
//	GtkWidget *p = gtk_event_box_new();
	
	struct pause_toggle_state* pts = g_new(struct pause_toggle_state,1);
	pts->image = GTK_IMAGE(gtk_image_new_from_stock("gtk-media-stop",GTK_ICON_SIZE_SMALL_TOOLBAR));
	pts->paused = FALSE;
	GtkWidget* p = gtk_event_box_new();
	gtk_widget_set_has_window(p, FALSE);
	g_signal_connect(p,"button-release-event",G_CALLBACK(pause_toggle), pts);
	gtk_container_add(GTK_CONTAINER(p),GTK_WIDGET(pts->image));
	gtk_widget_show_all(p);
	return p;
}

FM_DEFINE_MODULE(lxpanel_gtk, pauser);

LXPanelPluginInit fm_module_init_lxpanel_gtk = {
	.new_instance = new_instance,
	.init = init,
	.name = "Pause Player",
	.description = "Pause the currently running song player.",
};
