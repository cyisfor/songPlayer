#include "adjust.h"
#include <math.h>
#include <assert.h>
#include <stdio.h>

double A;

double HIGH;
double LOW;

void setupOffsetCurve(double halfwayPoint) {
    /* 0.9 = 1 / exp(A * 0.5)
     * log(0.9) = - A * 0.5
     * A = -log(0.9)*2
     */
  A = -log(1-halfwayPoint)*2;
  LOW = 1 / exp ( A * 0 );
  HIGH = 1 / exp ( A * 1 );
  assert(HIGH!=0);
  assert(HIGH-LOW != 0);
}

#define RESTRICT 0.5

double offsetCurve(double x) {
  return (1 / exp(A * x)-LOW)/(HIGH-LOW);
}
