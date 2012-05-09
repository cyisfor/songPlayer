#include "slice.h"

int IPCbind(const char* id);
void IPCsend(const char* id, slice what);
slice IPCrecv(int sock);
