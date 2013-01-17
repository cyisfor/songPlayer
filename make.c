#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <stdarg.h>
#include <assert.h>
#include <stdio.h>
#include <stdint.h>

struct string {
    char* str;
    ssize_t space;
    ssize_t len;
};

struct string* makeString(const char* what) {
    struct string* self = malloc(sizeof(struct string));
    if(what==NULL) {
        self->str = NULL;
        self->space = 0;
        self->len = 0;
    } else {
        self->str = strdup(what);
        self->space = strlen(what);
        self->len = self->space;
    }
}

struct string* stringAppend(struct string* what, const char* thing) {
    if(!what) {
        what = makeString(thing);
        return what;
    }
    ssize_t tlen = strlen(thing);
    while(what->len+tlen+1 > what->space) {
        what->space = ((what->len+tlen+1)/0x10+1)*0x10;
        what->str = realloc(what->str,what->space);
    }
    /* printf("String append %d+%d = %d < %d\n",what->len,tlen,what->len+tlen,
       what->space); */
    memcpy(what->str+what->len,thing,tlen);
    what->str[what->len+tlen]='\0';
    what->len += tlen;
    return what;
}

struct command {
    char** argv;
    int argc;
    struct string* base;
};

#define COMMAND_INITIALIZER { .argv = NULL, .argc = 0, .base = NULL }

void commandAppend(struct command* self, const char* args) {
    if(args==NULL) return;
    if(self->base) {
        self->base = stringAppend(self->base," ");
    }
    self->base = stringAppend(self->base,args);
}

void commandDerp(struct command* self) {
    self->base->str[self->base->len] = '\0';
}

void commandExecute(struct command* self) {
    char* saveptr = NULL;
    self->argv = NULL;
    self->argc = 0;
    char* token = strtok_r(self->base->str," \t",&saveptr);
    while(token) {
        ++self->argc;
        // printf("Token '%s' %d\n",token,self->argc);
        self->argv = realloc(self->argv,sizeof(char**)*(self->argc+1));
        self->argv[self->argc-1] = token;
        token = strtok_r(NULL," \t",&saveptr);
    }
    assert(self->argv);
    self->argv[self->argc] = NULL;
    execvp(self->argv[0],self->argv);
    exit(23);
}

void commandDestroy(struct command* self) {
    free(self->base->str);
    self->base = NULL;
    self->argv = NULL;
    self->argc = 0;
}

uint32_t step = 0;

void nextStep() {
    ++step;
}

int vCompile(const char* target, va_list list) {
    nextStep();
    struct stat tstat;
    int olderExists = (0 != stat(target,&tstat));
    // if no target, then olderExists is by default true
    struct command command = COMMAND_INITIALIZER;

    int initialized = 0;

#define INITYBOO if(0==initialized) {                    \
        initialized = 1;                                 \
        commandAppend(&command,"gcc");                  \
        commandAppend(&command,getenv("COMPILEARGS"));  \
        if(getenv("link")==NULL)                        \
            commandAppend(&command,"-c");               \
        else                                            \
            commandAppend(&command,getenv("LINKARGS")); \
        commandAppend(&command,"-o");                   \
        commandAppend(&command,target);                 \
    }
    if(olderExists) INITYBOO;

    for(;;) {
        const char* next = va_arg(list,const char*);
        if(NULL==next) break;
        if(!olderExists) {
            struct stat buf;
            stat(next,&buf);
            if(tstat.st_mtime < buf.st_mtime) {
                olderExists = 1;
            }
        }
        INITYBOO;
        commandAppend(&command,next);
    }

#undef INITYBOO

    if(!olderExists) return 0;

    commandDerp(&command);
    printf("%x > %s\n",step,command.base->str);
    int pid = fork();
    if(pid==0) {
        commandExecute(&command);
    }
    assert(pid>0);
    commandDestroy(&command);

    int status = 0;
    waitpid(pid,&status,0);
    if(WIFEXITED(status)) {
        if(WEXITSTATUS(status)!=0) {
            printf("Command failed with %d!\n",WEXITSTATUS(status));
            abort();
            exit(status);
        }
    } else if(WIFSIGNALED(status)) {
        printf("Command died with signal %d\n",WTERMSIG(status));
        raise(status); // XXX: derp
    }
    return 1;
}

struct string* slurp(const char* cmd, int amount, ...) {
    char** args = malloc(sizeof(const char*) * (amount+2));
    args[0] = strdup(cmd);
    va_list list;
    va_start(list,amount);
    int i;
    for(i=0;i<amount;++i) {
        const char* next = va_arg(list,const char*);
        args[i+1] = strdup(next);
    }
    args[amount+1] = NULL;
    int io[2];
    pipe(io);
    int pid = fork();
    if(pid==0) {
        close(io[0]);
        dup2(io[1],1);
        execvp(cmd,args);
        exit(23);
    } else {
        close(io[1]);
        char* buf = malloc(0x400);
        ssize_t amt = read(io[0],buf,0x400);
        if(amt==0x400) {
            printf("slurp should be only for small outputs :c\n");
            exit(3);
        }
        close(io[0]);
        int status = 0;
        waitpid(pid,&status,0);
        if(WIFEXITED(status)) {
            if(WEXITSTATUS(status)!=0) {
                printf("slurp %s failed with %d!\n",cmd,WEXITSTATUS(status));
                exit(status);
            }
        } else if(WIFSIGNALED(status)) {
            printf("slurp %s died with signal %d\n",cmd,WTERMSIG(status));
            raise(status); // XXX: derp
        }

        struct string* ret = makeString(NULL);
        int off = 0;
        while(isspace(buf[off])) {
            ++off;
            if(off==amt) {
                free(ret);
                free(buf);
                return NULL;
            }
        }
        if(off) {
            memmove(buf,buf+off,amt-off);
            amt -= off;
        }
        while(isspace(buf[amt-1])) --amt;
        buf[amt] = '\0';
        ret->str = buf;
        ret->space = 0x400;
        ret->len = amt;
        return ret;
    }
}

int compile(const char* target, ...) {
    unsetenv("link");
    va_list list;
    va_start(list,target);
    int ret = vCompile(target,list);
    va_end(list);
    return ret;
}

int linky(const char* target, ...) {
    setenv("link","1",1);
    va_list list;
    va_start(list,target);
    int ret = vCompile(target,list);
    va_end(list);
    return ret;
}

struct string* stringJoin(int amount, ...) {
    if(amount==0) return;
    va_list list;
    va_start(list,amount);
    int i;
    struct string* dest = va_arg(list,struct string*);
    for(i=1;i<amount;++i) {
        struct string* src = va_arg(list,struct string*);
        if(src && src->len) {
            if(dest && dest->len)
                dest = stringAppend(dest," ");
            dest = stringAppend(dest,src->str);
            free(src->str);
            free(src);
        }
    }
    return dest;
}

int main(int argc, char** argv) {

#define COMPILEO(n) compile(#n ".o",#n ".c",NULL);

    setenv("COMPILEARGS","-g",1);

    COMPILEO(make);

    if(linky("make","make.o",NULL)) {
        puts("reexec needed");
        execvp("./make",argv);
    }


    struct string* allc = stringJoin(3,
                                     makeString("-g"),
                                     slurp("libgcrypt-config",1,"--cflags"),
                                     slurp("pkg-config",2,"gstreamer-0.10","--cflags"));

    struct string* alll = stringJoin(3,
                                     makeString("-lpq"),
                                     slurp("libgcrypt-config",1,"--libs"),
                                     slurp("pkg-config",2,"gstreamer-0.10","--libs"));
    if(allc) {
        setenv("COMPILEARGS",allc->str,1);
        free(allc->str);
        free(allc);
    }
    if(alll) {
        setenv("LINKARGS",alll->str,1);
        free(alll->str);
        free(alll);
    }
    COMPILEO(player);
    COMPILEO(select);
    COMPILEO(adjust);
    COMPILEO(queue);
    COMPILEO(pq);
    COMPILEO(synchronize);
    COMPILEO(preparation);
    COMPILEO(urlcodec);
    COMPILEO(config);
    COMPILEO(signals);
    linky("player",
          "player.o","select.o","adjust.o",
          "queue.o","pq.o","synchronize.o",
          "preparation.o","urlcodec.o","config.o","signals.o",NULL);
    COMPILEO(hash);
    COMPILEO(import);
    linky("import","import.o","pq.o","preparation.o","hash.o",NULL);
    COMPILEO(rgscan);
    linky("replaygain_scanner","rgscan.o","pq.o","preparation.o","urlcodec.o",NULL);
    COMPILEO(scan);
    linky("scanner","scan.o","urlcodec.o",NULL);
    COMPILEO(durationscan);
    linky("dscanner","durationscan.o","urlcodec.o","pq.o","preparation.o",NULL);
    COMPILEO(best);
    linky("best","best.o","pq.o","preparation.o",NULL);
    COMPILEO(versioning);
    linky("migrate","versioning.o","pq.o",NULL);
    COMPILEO(next);
    linky("next","next.o","pq.o",NULL);
    COMPILEO(graph);
    linky("graph","graph.o","adjust.o",NULL);
    COMPILEO(mode);
    linky("mode","mode.o","pq.o",NULL);
    COMPILEO(testqueue);
    linky("testqueue","testqueue.o","pq.o",
          "adjust.o","preparation.o",
          "synchronize.o","select.o",
          "queue.o",NULL);
#undef COMPILEO
}
