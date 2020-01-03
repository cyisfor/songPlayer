#include "pq.h"
#include "preparation.h"
#include "queue.h"

int main(int argc, char *argv[])
{
	PQinit();
	queuePrepare();
	replay();
	return 0;
}
