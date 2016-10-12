#include "preparation.h"
#include <stdbool.h>
#include <string.h>

struct preparation {
	const char* name;
	const char* query;
	bool dirty;
};

preparation* memory = NULL;
int memn = 0;

bool prepare_needed_reset(void) {
	if(!pq_needed_reset()) return false;
	int i;
	for(i=0;i<memn;++i) {
		memory[i]->dirty = true;
	}
	return true;
}

void doprepare(preparation self) {
    PGresult* result = 
      PQprepare(PQconn,
                self->name,
								self->query,
                0,
                NULL);
    PQassert(result,result && PQresultStatus(result)==PGRES_COMMAND_OK);
		self->dirty = false;
}

PGresult *prepare_exec(preparation self,
                         int nParams,
                         const char * const *paramValues,
                         const int *paramLengths,
                         const int *paramFormats,
                         int resultFormat) {
	PGresult* res;
	do {
		if(self->dirty) {
			doprepare(self);
		}
		res =
			logExecPrepared(PQconn,
											self->name,
											nParams,paramValues,paramLengths,paramFormats,resultFormat);
	} while(prepare_needed_reset());
	return res;
}

preparation prepare(const char* query) {
	++memn;
	memory = realloc(memory,sizeof(preparation)*(memn));
	char buf[0x100] = "P";
	snprintf(buf+1,0x100-1,"%x",memn);
	// have to malloc separately or the pointer we return will be invalid after the next realloc!
	preparation self = malloc(sizeof(struct preparation));
	self->name = strdup(buf);
	self->query = query;
	self->dirty = true;
	memory[memn-1] = self;
	return self;
}
