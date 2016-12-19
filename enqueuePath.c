#include "queue.h"
#include "pq.h"

#include <limits.h>
#include <stdlib.h>

int main(int argc, char**argv) {
    int i;
    PQinit();
		queuePrepare();
    for(i=0;i<argc;++i) {
			char p[PATH_MAX];
        enqueuePath(realpath(argv[i],p));
				puts(p);
    }
    return 0;
}
