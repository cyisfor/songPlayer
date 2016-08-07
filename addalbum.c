#include "pq.h"
#include "preparation.h"

int main(int argc, char *argv[])
{
	preparation_t queries[] = {
    { "addAlbum",
      "INSERT INTO queue (recording) SELECT recording FROM recordings WHERE recordings.album = $1 EXCEPT SELECT recording FROM queue"}
	};
	prepareQueries(queries);
	int i;
	for(i=1;i<argc;++i) {
		long album = strtol(argv[i],NULL);
		if(err == NULL || *err == '\0') continue;
		printf("Queuing album %ld\n",album);
		const char* values[] = { argv[i] };
		const int lengths[] = { strlen(argv[i]) };
		const int fmt[] = { 0 };
		logExecPrepared(PQconn,"addAlbum",
										1,values,lengths,fmt,0);
	}
	
	return 0;
}
