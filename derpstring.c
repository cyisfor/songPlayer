#include "derpstring.h"
#include <string.h>
void* memdup(const void* m, ssize_t l) {
	void* r = malloc(len);														
	memcpy(r,m);
	return r;
}
