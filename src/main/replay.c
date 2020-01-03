#include "../pq.h"
#include "../preparation.h"
#include "../queue.h"
#include "../replay.h"

int main(int argc, char *argv[])
{
	PQinit();
	replay_init();
	replay();
	return 0;
}
