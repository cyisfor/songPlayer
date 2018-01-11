#include "pq.h"
#include "preparation.h"
#include <string.h>

int main(int argc, char *argv[])
{
	PQinit();
	preparation addAlbum = prepare(
      "INSERT INTO queue (id,recording) SELECT "
			"album_order.which + 1 + "
			"coalesce((select max(id) from queue),0),recordings.id FROM recordings "
			"INNER JOIN songs ON songs.id = recordings.song "
			"INNER JOIN album_order ON songs.id = album_order.song "
			"WHERE recordings.album = $1 AND album_order.album = $1"
	);
	int i;
	char* err = NULL;
	for(i=1;i<argc;++i) {
		long album = strtol(argv[i],&err,10);
		if(err == NULL || *err != '\0') {
			printf("not quoe %s\n",err);
			continue;
		}
		printf("Queuing album %ld\n",album);
		const char* values[] = { argv[i] };
		const int lengths[] = { strlen(argv[i]) };
		const int fmt[] = { 0 };
		prepare_exec(addAlbum,
										1,values,lengths,fmt,0);
	}
	
	return 0;
}
