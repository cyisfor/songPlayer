#include "settitle.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h> // strcmp


static const char* prefix(const char* term) {
    if(term) 
        if(0==strcmp(term,"screen"))
            return "\033_";
    return "\033]0;";
}

static const char* suffix(const char* term) {
    if(term) 
        if(0==strcmp(term,"screen"))
            return "\a\\";
    return "\a";
}

void settitle(const char* title) {
    const char* term = getenv("TERM");
    fputs(prefix(term),stdout);
    fputs(title,stdout);
    fputs(suffix(term),stdout);
}
