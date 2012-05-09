int selfpipe[2];
static void selfpipe_sigh(int n)
{
    write(selfpipe[1], "",1);
}
void waittimeout_setup(void)
{
    static struct sigaction act;
    if (pipe(selfpipe) == -1) { abort(); }
    fcntl(selfpipe[0],F_SETFL,fctnl(selfpipe[0],F_GETFL)|O_NONBLOCK);
    fcntl(selfpipe[1],F_SETFL,fctnl(selfpipe[1],F_GETFL)|O_NONBLOCK);
    memset(&act, 0, sizeof(act));
    act.sa_handler = selfpipe_sigh;
    act.sa_flags |= 0;
    sigaction(SIGCHLD, &act, NULL);
}

int waittimeout(void)
{
    static char dummy[4096];
    fd_set rfds;
    struct timeval tv;
    int died = 0, st;

    tv.tv_sec = 5;
    tv.tv_usec = 0;
    FD_ZERO(&rfds);
    FD_SET(selfpipe[0], &rfds);
    if (select(selfpipe[0]+1, &rfds, NULL, NULL, &tv) > 0) {
       while (read(selfpipe[0],dummy,sizeof(dummy)) > 0);
       while (waitpid(-1, &st, WNOHANG) != -1) died++;
    }
    return died;
}
