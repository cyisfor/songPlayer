void pause(sem_t* sem) {
  sem_wait(sem);
}

void resume(sem_t* sem) {
  while(sem_trywait(sem)==0) {
    sleep(1);
    sem_post(sem);
  }
}
