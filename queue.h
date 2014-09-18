#include <stdint.h>

void queueSetup(void);

void setupOffsetCurve(double halfwayPoint);
double offsetCurve(double x);
void enqueue(const char* id);

extern volatile uint8_t queueInterrupted;
