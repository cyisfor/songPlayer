#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>

#define REPETITIONS 0x10000
#define NUMBINS 0x100

int main(void) {
    int i;
    uint32_t bins[NUMBINS] = {};
    srand48(time(NULL));
    for(i=0;i<REPETITIONS;++i) {
        double randF = drand48();
        bins[(int)(randF * NUMBINS)]++;
    }
    for(i=0;i<NUMBINS;++i) {
        if(bins[i]==0) {
            bins[i] = 5;
        }
        printf("%d\n",bins[i]);
    }
}
