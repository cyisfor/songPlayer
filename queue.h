#include <stdint.h>

void queueStart(void);
void queuePrepare(void);
void queueRescore(void);
void setupOffsetCurve(double halfwayPoint);
double offsetCurve(double x);
void enqueue(const char* id);

extern volatile uint8_t queueInterrupted;
