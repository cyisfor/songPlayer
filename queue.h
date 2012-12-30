#include <stdint.h>

void queueSetup(void);

void setupOffsetCurve(double halfwayPoint);
double offsetCurve(double x);

extern volatile uint8_t queueInterrupted;
