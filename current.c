#include "pq.h"
#include "preparation.h"
#include "settitle.h"
#include "o/current.glade.ch"

#include <gtk/gtk.h>
#include <stdio.h>
#include <error.h>

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

#define ID_COLUMN 7

#define NUM_ROWS (sizeof(rows)/sizeof(*rows))

#define LENSTR(a) a, (sizeof(a)-1)

#define assert(a) if(!(a)) {						\
	error(23,0,"oops! " #a);					\
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
  GError* gerror = NULL;
  gtk_css_provider_load_from_data
	(odd_style,
	 LENSTR("GtkBox { background-color: white; }\n"),
	 &gerror);
  assert(gerror==NULL);

  GtkBuilder* builder = gtk_builder_new_from_string(gladeFile,gladeFileSize);
  GtkWidget* top = GTK_WIDGET(gtk_builder_get_object(builder,"top"));
  GtkGrid* props = GTK_GRID(gtk_builder_get_object(builder,"properties"));

  GtkLabel* title =
  	GTK_LABEL(gtk_builder_get_object(builder,"title"));

  GtkLabel* labels[NUM_ROWS];
  int i;
  for(i=0;i<NUM_ROWS;++i) {
	printf("boop %s\n",rows[i]);
	GtkLabel* name = GTK_LABEL(gtk_label_new(rows[i]));
	gtk_label_set_xalign(name,0);
	labels[i] = GTK_LABEL(gtk_label_new(""));
	gtk_label_set_line_wrap (labels[i],TRUE);
	gtk_widget_set_hexpand (GTK_WIDGET(labels[i]),TRUE);
	gtk_label_set_xalign(labels[i],0);
	gtk_grid_insert_row (props, i);
	void yoinkle(int column, GtkWidget* what) {
	  gtk_widget_set_vexpand(what,FALSE);
	  // no reason to make a huge style framework just for some padding
	  // tricky... put it in a box, that has padding
	  // then put the box in the grid
	  gtk_widget_set_margin_start (what, 2);
	  GtkWidget* padding = gtk_box_new(GTK_ORIENTATION_HORIZONTAL,0);
	  gtk_box_pack_start(GTK_BOX(padding),what,TRUE,TRUE,2);
	  
	  if(i % 2 == 1) {
		gtk_style_context_add_provider
		  (gtk_widget_get_style_context(padding),
		   GTK_STYLE_PROVIDER(odd_style),
		   GTK_STYLE_PROVIDER_PRIORITY_USER);
	  }

	  gtk_grid_attach(props, padding,column,i,1,1);
	}
	yoinkle(0,GTK_WIDGET(name));
	yoinkle(1,GTK_WIDGET(labels[i]));
  }

  int last_id = -1;
  
  gboolean update_properties(gpointer udate) {
	PGresult* result =
	  logExecPrepared(PQconn,"getTopSong",
					  0,NULL,NULL,NULL,0);

	int i = 0;
	if(PQntuples(result) == 0) {
	  puts("(no reply)");
	} else {
	  int cur_id = atol(PQgetvalue(result,0,ID_COLUMN));
	  if(cur_id == last_id) {
		puts("(no change)");
	  } else {
		last_id = cur_id;
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
			static char titlebuf[0x100] = "Current Song Playing - ";
			strncpy(titlebuf+sizeof("Current Song Playing - ")-1,
					value,
					0x100-(sizeof("Current Song Playing - ")-1));
			gtk_window_set_title(top,titlebuf);
			gtk_label_set_text(title,value);
			printf("erum %s\n",value);
		  }
		
		  gtk_label_set_text(labels[i],value);
		}
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
