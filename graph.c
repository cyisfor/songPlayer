#include "queue.h"
#include <stdio.h>

int main(void) {
  setupOffsetCurve(0.9);
  double x;
  for(x=0;x<1;x+=0.01) {
    printf("%lf %lf\n",x,offsetCurve(x));
  }
}

