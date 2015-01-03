#include "pq.h"
#include "preparation.h"

extern const char* gladeFile;
extern long unsigned int gladeFileSize;

#include <gtk/gtk.h>
#include <glib.h>

#include <stdint.h>
#include <string.h>


uint32_t page = 0;
#define pagesize 0x10

const char derpagesize[] = "16";

static void fillNext(GtkTreeSelection* selection, GtkListStore* model) {
    uint32_t i;
    gtk_list_store_clear(model);

    static char offset[0x100];
    ssize_t len = snprintf(offset,0x100,"%d",page*pagesize);
    
    const char* values[] = { offset, derpagesize };
    const int lengths[] = { len, sizeof(derpagesize)  };
    const int fmt[] = { 0, 0 };

    PGresult* result = PQexecParams(PQconn,"getpage",1,NULL,values,lengths,fmt,0);
    GtkTreeIter iter = {};
    gtk_tree_model_get_iter_first(GTK_TREE_MODEL(model),&iter);
    for(i=0;i<PQntuples(result);++i) {
        gtk_list_store_append(model,&iter);
        gtk_list_store_set(model,&iter,0,strtof(PQgetvalue(result,i,0),NULL),
                1,PQgetvalue(result,i,1),
                2,PQgetvalue(result,i,2),
                -1);
    }

    PQclear(result);

    ++page;

}

void rate(GtkTreeModel* model, GtkTreePath* path, GtkTreeIter* iter, gpointer data) {
    uint8_t rating = (uint8_t) (uintptr_t) data;
    static char srating[0x10];
    ssize_t ratlen = snprintf(srating,0x10,"%d",rating);
    gchararray idstr = NULL;
    gtk_tree_model_get(model,iter,2,&idstr);
    const char* values[] = { srating, idstr };
    const int lengths[] = { ratlen, strlen(idstr) };
    const int fmt[] = { 0, 0 };
    printf("Rating %s %d\n",idstr,rating);
    //PQclear(PQexecParams(PQconn,"rate",2,NULL,values,lengths,fmt,0));
}

static void yay(GtkWidget* btn, GtkTreeSelection* selection) {
    gtk_tree_selection_selected_foreach(selection,rate,(void*)1);

}

static void nay(GtkWidget* btn, GtkTreeSelection* selection) {
    gtk_tree_selection_selected_foreach(selection,rate,(void*)-1);

}

int main(void) {
    preparation_t queries[] = {
        { "rate",
            "SELECT connectionStrength((select id from mode),$2,$1)" },
        { "getpage",
            "select rating,title,id from connections inner join songs on connections.blue = songs.id where red = (select id from mode) order by strength desc OFFSET $1 LIMIT $2;" }
    };
    PQinit();
    prepareQueries(queries);

    GtkBuilder* builder = gtk_builder_new_from_string(gladeFile,gladeFileSize);
    GtkWidget* top = GTK_WIDGET(gtk_builder_get_object(builder,"top"));
    GtkTreeSelection* selection = GTK_TREE_SELECTION(
            gtk_builder_get_object(builder,"song-selection"));
    GtkButton* rateup = GTK_BUTTON(
            gtk_builder_get_object(builder,"rateup"));
    GtkButton* ratedown = GTK_BUTTON(
            gtk_builder_get_object(builder,"ratedown"));

    g_signal_connect(G_OBJECT(rateup),"clicked",G_CALLBACK(yay),selection);
    g_signal_connect(G_OBJECT(ratedown),"clicked",G_CALLBACK(nay),selection);

    GtkListStore* model = GTK_LIST_STORE(
            gtk_builder_get_object(builder,"songs"));

    fillNext(selection,model);
    gtk_widget_show_all(top);
    gtk_main();
}
