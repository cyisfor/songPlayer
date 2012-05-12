void setNumQueued(uint8_t);
void waitUntilSongInQueue(void);
void waitUntilQueueNeeded(void);
void songOutOfQueue(void);
void fillQueue(int (*addOne)(void));
