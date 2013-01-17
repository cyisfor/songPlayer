#include "synchronize.h"

#include <glib.h>

#include <pthread.h>
#include <assert.h>
#include <stdio.h>

pthread_mutex_t queueLock = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t _checkQueue = PTHREAD_COND_INITIALIZER;
pthread_cond_t _songInQueue = PTHREAD_COND_INITIALIZER;

#define DESIRED 0x3
uint8_t queueSize = 0;

#ifdef SPAMMY

void message_w_threadid(const char* fmt, ...) {
    fprintf(stdout,"(%lx) ",pthread_self());
    va_list list;
    va_start(list,fmt);
    vfprintf(stdout,fmt,list);
    va_end(list);
    fputc('\n',stdout);
}

#else

#define message_w_threadid(...)

#endif

void setNumQueued(uint8_t num) {
  // don't need a lock at this point...
  message_w_threadid("Queue SET %x",num);
  queueSize = num;
}

void waitUntilSongInQueue(void) {
  message_w_threadid("lock1");
  pthread_mutex_lock(&queueLock);
  do {
    pthread_cond_broadcast(&_checkQueue);
    message_w_threadid("WAIT songInQueue\n");
    pthread_cond_wait(&_songInQueue,&queueLock);
    message_w_threadid("yay songInQueue? %x\n",queueSize);
  } while (queueSize==0);
  pthread_mutex_unlock(&queueLock);
  message_w_threadid("ulock1");
}

void waitUntilQueueFull(void) {
  message_w_threadid("into queue full wait");
  pthread_mutex_lock(&queueLock);
  do {
    pthread_cond_broadcast(&_checkQueue);
    message_w_threadid("WAIT queueFull\n");
    pthread_cond_wait(&_songInQueue,&queueLock);
    message_w_threadid("yay queueFull? %x %x\n",queueSize,DESIRED);
  } while (queueSize<DESIRED);
  pthread_mutex_unlock(&queueLock);
  message_w_threadid("outof queue full wait");
}
void waitUntilQueueNeeded(uint8_t (*currentSize)(void)) {
  message_w_threadid("lock2");
  pthread_mutex_lock(&queueLock);
  while (queueSize >= DESIRED) {
    pthread_cond_broadcast(&_songInQueue);
    message_w_threadid("WAIT queueNeeded\n");
    pthread_cond_wait(&_checkQueue,&queueLock);
    queueSize = currentSize();
  }
  if(queueSize > 0)
    pthread_cond_broadcast(&_songInQueue);
  pthread_mutex_unlock(&queueLock);
  message_w_threadid("ulock2");
}

void songOutOfQueue(void) {
  message_w_threadid("lock3");
  pthread_mutex_lock(&queueLock);
  message_w_threadid("Queue DEC %x",queueSize);
  if(queueSize>0)
    --queueSize;
  pthread_cond_broadcast(&_checkQueue);
  pthread_mutex_unlock(&queueLock);
  message_w_threadid("ulock3");
}

void fillQueue(uint8_t (*addOne)(void)) {
  for(;;) {
    message_w_threadid("lock4");
    pthread_mutex_lock(&queueLock);
    if(queueSize > 0)
      pthread_cond_broadcast(&_songInQueue);
    if(queueSize >= DESIRED) {
      pthread_mutex_unlock(&queueLock);
      message_w_threadid("ulock4++");
      break;
    }
    pthread_mutex_unlock(&queueLock);
    uint8_t newsize = addOne();
    /* Since the size might have been zeroed by mode,
       have to set the size by the database not by a
       parallel memory size counter;
    */
    pthread_mutex_lock(&queueLock);
    message_w_threadid("Queue INC %x",queueSize);
    //++queueSize;
    queueSize = newsize;
    pthread_cond_broadcast(&_songInQueue);
    pthread_mutex_unlock(&queueLock);
    message_w_threadid("ulock4");
  }
}
