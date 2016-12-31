#include <stdlib.h> // ssize_t

typedef struct string {
	char* base;
	ssize_t len;
} string;

#define STRINGDUP(s,start,len) {								\
		s.base = malloc(len);												\
		memcpy(s.base,start,len);										\
		s.len = len;																\
	}

#define UNSTR(s) s.base, s.len
