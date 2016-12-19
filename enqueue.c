#include "queue.h"
#include "pq.h"

#include <stdio.h>

static void byline(void) {
	char* line = NULL;
	size_t space = 0;
	for(;;) {
		ssize_t n = getline(&line,&space);
		if(n <= 0) return;
		enqueue(line,n);
	}
}

int main(int argc, char**argv) {
    int i;
    PQinit();
		queuePrepare();
 		if(argc == 1) {
			byline();
		} else for(i=1;i<argc;++i) {
        enqueue(argv[i],strlen(argv[i]);
    }
    return 0;
}
