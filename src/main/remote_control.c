#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/select.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>
#include <assert.h>

int kbd = -1;
char key_map[KEY_MAX/8 + 1];    //  Create a byte array the size of the number of keys

static void getkb(void) {
    memset(key_map, 0, sizeof(key_map));    //  Initate the array to zero's
    ioctl(kbd, EVIOCGKEY(sizeof(key_map)), key_map);    //  Fill the keymap with the current keyboard state
}

// http://stackoverflow.com/questions/3649874/how-to-get-keyboard-state-in-linux
static int pressed(int key) {    
    int keyb = key_map[key/8];  //  The key we want (and the seven others arround it)
    int mask = 1 << (key % 8);  //  Put a one in the same column as out key state will be in;

    return !(keyb & mask);  //  Returns true if pressed otherwise false
}

int sshfd;
int sshpid = -1;

static void initssh() {
    int p[2];
    pipe(p);
    int pid = fork();
    if(pid == 0) {
        close(p[1]);
        dup2(p[0],0);
        execlp("ssh","ssh","192.168.1.5","/bin/sh");
    }
    sshpid = pid;
    sshfd = p[1];
    close(p[0]);
}

int status;
void reinitssh() {
    if(waitpid(sshfd,&status,WNOHANG) == 0) return;
    initssh();
}

void send(const char* command) {
    reinitssh();
    write(sshfd,command,strlen(command));
    write(sshfd,"\n",1);
}

int main(void) {
    kbd = open("/dev/input/by-path/platform-i8042-serio-0-event-kbd", O_RDONLY);
    assert(kbd > 0);
    initssh();
    fd_set rdfs;
    FD_ZERO(&rdfs);
    FD_SET(0,&rdfs);
    char shifted = 0;

    fcntl(0,F_SETFL,fcntl(0,F_GETFL) | O_NONBLOCK);
    char buf[0x100];

    for(;;) {
        select(1,&rdfs,NULL,NULL,NULL);
        getkb();
        shifted = (pressed(KEY_LEFTSHIFT) || pressed(KEY_RIGHTSHIFT));
        if(pressed(KEY_I)) {
            send("mode=i ~/code/songpicker/who");
        } else if(pressed(KEY_M) || pressed(KEY_B)) {
            send("mode=m ~/code/songpicker/who");
        } else if(pressed(KEY_SPACE)) {
            if(shifted)
                send("rating=-3 ~/code/songpicker/next");
            else
                send("rating=-1 ~/code/songpicker/next");
        } else if(pressed(KEY_C)) {
            send("~/code/songpicker/current");
        }
        write(1,"Got ",4);
        for(;;) {
            int amt = read(0,buf,0x100);
            if(amt<0) break;
            write(1,buf,amt);
        }
        write(1,"\n",1);
    }
    return 0;
}
