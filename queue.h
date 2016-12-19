#include <stdint.h>

void queueStart(void);
void queuePrepare(void);
void queueRescore(void);
void setupOffsetCurve(double halfwayPoint);
double offsetCurve(double x);
void enqueue(const char* id,uint32_t len);
void enqueuePath(const char* path);

extern volatile uint8_t queueInterrupted;
