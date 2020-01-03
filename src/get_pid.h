#include <stdlib.h> // ssize_t
#include <stdbool.h>

int get_pid(const char* application_name, ssize_t len);
bool declare_pid(const char* application_name);
void get_pid_init(void);
