#include "pq.h"
#include "preparation.h"
#include "settitle.h"

extern const char gladeFile[];
extern long unsigned int gladeFileSize;

#include <gtk/gtk.h>
#include <stdio.h>

// meh!
const char* rows[] = {
  "Title",
  "Artist",
  "Album",
  "Duration",
  "Rating",
  "Average",
  "Played",
  "Id"
};

#define NUM_ROWS (sizeof(rows)/sizeof(*rows))

#define LENSTR(a) a, (sizeof(a)-1)

#define assert(a) if(!a) {						\
	error(23,23,"oops! " #a);					\
  }

int main (int argc, char ** argv)
{
  PQinit();
  preparation_t queries[] = {
    "getTopSong",
      "SELECT songs.title,artists.name as artist,albums.title as album,recordings.duration,"
          "(SELECT connections.strength FROM connections WHERE connections.blue = songs.id AND connections.red = (select id from mode)) AS rating,"
    "(SELECT score FROM ratings WHERE ratings.id = songs.id) AS score,"
          "(SELECT AVG(connections.strength) FROM connections WHERE connections.red = (select id from mode)) AS average, "
          "songs.played, songs.id "
          "FROM queue "
          "INNER JOIN recordings ON recordings.id = queue.recording "
          "INNER JOIN songs ON recordings.song = songs.id "
          "LEFT OUTER JOIN albums ON recordings.album = albums.id "
          "LEFT OUTER JOIN artists ON recordings.artist = artists.id "
          "ORDER BY queue.id ASC LIMIT 2"
  };
  prepareQueries(queries);

  gtk_init(&argc,&argv);

  GtkCssProvider * odd_style = gtk_css_provider_get_default ();
  GError* error = NULL;
  gtk_css_provider_load_from_data
	(odd_style,
	 LENSTR("GtkLabel { background-color: shade(@base_color, 0.9); }\n"),
	 &error);
  assert(error==NULL);

  GtkBuilder* builder = gtk_builder_new_from_string(gladeFile,gladeFileSize);
  GtkWidget* top = GTK_WIDGET(gtk_builder_get_object(builder,"top"));
  GtkBox* props = GTK_BOX(gtk_builder_get_object(builder,"properties"));

  GtkLabel* title =
  	GTK_LABEL(gtk_builder_get_object(builder,"title"));

  GtkLabel* labels[NUM_ROWS];
  int i;
  for(i=0;i<NUM_ROWS;++i) {
	GtkLabel* name = gtk_label_new(rows[i]);
	labels[i] = gtk_label_new(NULL);
	GtkBox* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL,0);
	if(i % 2 == 1) {
	  gtk_style_context_add_provider
		(GTK_STYLE_PROVIDER(odd_style),
		 gtk_widget_get_style_context(GTK_WIDGET(box)),
		 GTK_STYLE_PROVIDER_PRIORITY_USER);
	}

	gtk_box_pack_start(box,name,false,false,2);
	gtk_box_pack_start(box,labels[i],true,true,2);
  }

  gboolean update_properties(gpointer udate) {
	PGresult* result =
	  logExecPrepared(PQconn,"getTopSong",
					  0,NULL,NULL,NULL,0);
	int i = 0;
	if(PQntuples(result) == 0) {
	  puts("(no reply)");
	} else {
	  for(;i<PQnfields(result);++i) {
		const char* value = PQgetvalue(result,0,i);
		if(value == NULL) {
		  value = "(null)";
		} else if(i==3) {
		  static char real_value[0x100];
		  unsigned long duration = atol(value) / 1000000000;
		  if(duration > 60) {
			int seconds = duration % 60;
			int amt = snprintf(real_value,0x100,"%um",duration / 60);
			if(seconds) {
			  amt += snprintf(real_value+amt,
							  0x100-amt,
							  " %us",seconds);
			}
		  } else {
			snprintf(real_value,0x100,"%us",duration);
		  }
		  value = real_value;
		} else if(i==0) {
		  gtk_label_set_text(title,value);
		}
		gtk_label_set_text(labels[i],value);
	  }
	}
	PQclear(result);
  }

  g_signal_connect(top,"destroy",gtk_main_quit,NULL);
  g_timeout_add_seconds(2, update_properties,NULL);
  gtk_widget_show_all(top);
  gtk_main();

  return 0;
}
