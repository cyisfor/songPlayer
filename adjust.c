#include "adjust.h"
#include <math.h>
#include <assert.h>

double A;
double eA;

void setupOffsetCurve(double halfwayPoint) {
  A = ((double)log(0.5)) / (halfwayPoint - 1);
  eA = exp(A);
}

#define RESTRICT 1.0

double offsetCurve(double x) {
  assert(eA!=0);
  return (1 - exp(A * x) / eA) * RESTRICT;
}
