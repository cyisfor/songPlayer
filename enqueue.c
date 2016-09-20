#include "queue.h"
#include "pq.h"


int main(int argc, char**argv) {
    int i;
    PQinit();
		queuePrepare();
    for(i=0;i<argc;++i) {
        enqueue(argv[i]);
    }
    return 0;
}
