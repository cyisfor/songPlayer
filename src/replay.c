#include "preparation.h"
#include "queue.h"

#include <assert.h> // 


static preparation getTopRecording = NULL;
void replay_init(void) {
	queue_init();
	getTopRecording = prepare
		("SELECT queue.recording"
		 " FROM queue ORDER BY queue.id ASC LIMIT 1");
	assert(getTopRecording);
}

void replay(void) {
	PGresult* result = 
		prepare_exec(getTopRecording,
					 0,NULL,NULL,NULL,0);
	int rows = PQntuples(result);
	if(rows == 0) {
		exit(23);
	}
	const char* recording = PQgetvalue(result,0,0);
	enqueue(recording,PQgetlength(result,0,0));
}
