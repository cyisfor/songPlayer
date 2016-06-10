#include "adjust.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    setupOffsetCurve(0.5);

    assert(0.0==offsetCurve(0.0));
    assert(1.0==offsetCurve(1.0));
    puts("A-OK");
}
