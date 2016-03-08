#include "pq.h"
#include "preparation.h"
#include "settitle.h"

extern const char gladeFile[];
extern long unsigned int gladeFileSize;

#include <gtk/gtk.h>
#include <stdio.h>

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

  gtk_init(argc,argv);

  GtkBuilder* builder = gtk_builder_new_from_string(gladeFile,gladeFileSize);
  GtkWidget* top = GTK_WIDGET(gtk_builder_get_object(builder,"top"));
  GtkListStore* props =
	GTK_LIST_STORE(gtk_builder_get_object(builder,"properties"));
  GtkLabel* title =
  	GTK_LABEL(gtk_builder_get_object(builder,"title"));
  gboolean update_properties(gpointer udate) {
	PGresult* result =
	  logExecPrepared(PQconn,"getTopSong",
					  0,NULL,NULL,NULL,0);
	int i = 0;
	if(PQntuples(result) == 0) {
	  puts("(no reply)");
	} else {
	  gtk_list_store_clear(props);
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
      
		gtk_list_store_set(current_row,
						   props,
						   0,
						   PQfname(result,i),
						   1,
						   value);
	  }
	}
	PQclear(result);
  }

  g_timeout_add_seconds(2, update_properties,NULL);
  gtk_main();

  return 0;
}
