#include <stdint.h>
void setNumQueued(uint8_t);
void waitUntilSongInQueue(void);
void waitUntilQueueFull(void);
void waitUntilQueueNeeded(uint8_t (*currentSize)(void));
void songOutOfQueue(void);
void fillQueue(uint8_t (*addOne)(void));
