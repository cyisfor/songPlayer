#include "adjust.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    setupOffsetCurve(0.7);

    assert(0.0==offsetCurve(0.0));
    assert(1.0==offsetCurve(1.0));
		int i;
		for(i=0;i<1000;++i) {
			float x = i / 1000.0;
			printf("%f %f\n",x,offsetCurve(x));
		}
}
