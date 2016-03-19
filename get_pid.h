#include <stdlib.h> // ssize_t
#include <stdbool.h>

void get_pid_init(void);
int get_pid(const char* application_name, ssize_t len);
bool get_pid_declare(void);
