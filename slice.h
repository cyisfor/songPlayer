#ifndef SLICE_INCLUDED
#define SLICE_INCLUDED
#include <stdlib.h>

typedef struct {
	char* data;
	ssize_t start;
	ssize_t end;
} slice;

#define DEFINE_SLICE(name,str) slice name = { str, 0, strlen(str) };

#endif /* SLICE_INCLUDED */
