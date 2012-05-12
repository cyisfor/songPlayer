#include <stdint.h>
void setNumQueued(uint8_t);
void waitUntilSongInQueue(void);
void waitUntilQueueNeeded(void);
void songOutOfQueue(void);
void fillQueue(uint8_t (*addOne)(void));
