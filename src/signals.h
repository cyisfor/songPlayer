#include <signal.h>
void onSignal(int signal, void (*handler)(int));
void signalsSetup(void);
