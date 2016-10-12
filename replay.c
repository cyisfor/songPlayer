#include "pq.h"
#include "preparation.h"
#include "queue.h"

int main(int argc, char *argv[])
{
	PQinit();
	queuePrepare();
	preparation getTopRecording = prepare
		("SELECT queue.recording"
		 " FROM queue ORDER BY queue.id ASC LIMIT 1");

	PGresult* result = 
		prepare_exec(getTopRecording,
										0,NULL,NULL,NULL,0);
	int rows = PQntuples(result);
	if(rows == 0) {
		exit(23);
	}
	const char* recording = PQgetvalue(result,0,0);
	printf("re-queueing %s\n",recording);
	enqueue(recording);
	return 0;
}
