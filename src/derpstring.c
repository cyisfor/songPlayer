#include "derpstring.h"
#include <string.h>
void* memdup(const void* m, ssize_t l) {
	void* r = malloc(l);														
	memcpy(r,m,l);
	return r;
}
