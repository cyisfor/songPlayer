#ifndef _DERPSTRING_H_
#define _DERPSTRING_H_

#include <stdlib.h> // ssize_t

typedef struct string {
	char* base;
	ssize_t len;
} string;

void* memdup(void* m, ssize_t l);

#define STRINGDUP(s,start,ashtlen) {								\
		s.base = memdup(start,ashtlen);									\
		s.len = ashtlen;																\
	}

#define UNSTR(s) s.base, s.len

#endif /* _DERPSTRING_H_ */
