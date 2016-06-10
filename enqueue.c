#include "queue.h"
#include "pq.h"


int main(int argc, char**argv) {
    int i;
    PQinit();
    for(i=0;i<argc;++i) {
        enqueue(argv[i]);
    }
    return 0;
}
