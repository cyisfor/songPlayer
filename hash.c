#include "hash.h"

#include <gcrypt.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <assert.h>
#include <unistd.h> // read
#include <sys/wait.h> // waitpid

char lookup[] = "0123456789abcdef";

static char* hexencode(char* what) {
    int len = gcry_md_get_algo_dlen(GCRY_MD_SHA256);
    char* hex = malloc(len*2+1);
    int i;
    for(i=0;i<len;++i) {
        hex[2*i] = lookup[what[i] & 0xf];
        hex[2*i+1] = lookup[(what[i] >> 4) & 0xf];
    }
    hex[2*len] = '\0';
    return hex;
}

char* hash(const char* path) {
    static gcry_md_hd_t hd = NULL;
    gcry_error_t err;
    if(hd) {
        gcry_md_reset(hd);
    } else {
        err = gcry_md_open(&hd,GCRY_MD_SHA256,0);
        assert(err==GPG_ERR_NO_ERROR);
    }
    int fd = open(path,O_RDONLY);
    assert(fd>0);
    char buf[0x1000];
    for(;;) {
        ssize_t amt = read(fd,buf,0x1000);
        if(amt <= 0) break;
        gcry_md_write(hd,buf,amt);
    }
    close(fd);
    return hexencode((char*)gcry_md_read(hd,GCRY_MD_SHA256));
}
