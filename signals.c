#include "signals.h"
#include <glib.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>

// adapted from http://askra.de/software/gtk-signals/x2992.html

int signal_pipe[2];

typedef void (*signal_handler)(int);
signal_handler handlers[0x100];

/* 
 * The unix signal handler.
 * Write any unix signal into the pipe. The writing end of the pipe is in 
 * non-blocking mode. If it is full (which can only happen when the 
 * event loop stops working) signals will be dropped.
 */
static void pipe_signals(int signal)
{
  if(write(signal_pipe[1], &signal, sizeof(int)) != sizeof(int))
    {
      g_warning("unix signal %d lost\n", signal);
    }
}
  
/* 
 * The event loop callback that handles the unix signals. Must be a GIOFunc.
 * The source is the reading end of our pipe, cond is one of 
 *   G_IO_IN or G_IO_PRI (I don't know what could lead to G_IO_PRI)
 * the pointer d is always NULL
 */
static gboolean deliver_signal(GIOChannel *source, GIOCondition cond, gpointer d)
{
  GError *error = NULL;		/* for error handling */

  /* 
   * There is no g_io_channel_read or g_io_channel_read_int, so we read
   * char's and use a union to recover the unix signal number.
   */
  union {
    gchar chars[sizeof(int)];
    int signal;
  } buf;
  GIOStatus status;		/* save the reading status */
  gsize bytes_read;		/* save the number of chars read */
  char text[40];		/* the text that will appear in the label */
  

  /* 
   * Read from the pipe as long as data is available. The reading end is 
   * also in non-blocking mode, so if we have consumed all unix signals, 
   * the read returns G_IO_STATUS_AGAIN. 
   */
  while((status = g_io_channel_read_chars(source, buf.chars, 
		     sizeof(int), &bytes_read, &error)) == G_IO_STATUS_NORMAL)
    {
      g_assert(error == NULL);	/* no error if reading returns normal */

      /* 
       * There might be some problem resulting in too few char's read.
       * Check it.
       */
      if(bytes_read != sizeof(int)){
	g_warning("lost data in signal pipe (expected %lu, received %lu)\n",
                  sizeof(int), bytes_read);
	continue;	      /* discard the garbage and keep fingers crossed */
      }

      /* Ok, we read a unix signal number, so let the label reflect it! */
      g_message("received signal %d", buf.signal);
      handlers[buf.signal](buf.signal);
    }
  
  /* 
   * Reading from the pipe has not returned with normal status. Check for 
   * potential errors and return from the callback.
   */
  if(error != NULL){
    g_error("reading signal pipe failed: %s\n", error->message);
    exit(1);
  }
  if(status == G_IO_STATUS_EOF){
    g_error("signal pipe has been closed\n");
    exit(1);
  }

  g_assert(status == G_IO_STATUS_AGAIN);
  return (TRUE);		/* keep the event source */
}

void onSignal(int signal, void (*handler)(int)) {
  struct sigaction action;
  sigset_t sigactionSucks;
  sigemptyset(&sigactionSucks);
  action.sa_handler = pipe_signals;
  action.sa_mask = sigactionSucks;
  action.sa_flags = 0;
  handlers[signal] = handler;
  sigaction(signal,&action,NULL);
}
  
void signalsSetup(void) {
  GError *error = NULL;		/* for error handling */
  memset(handlers,0,sizeof(handlers));

  if(pipe(signal_pipe)) {
    perror("pipe");
    exit(1);
  }
  long fd_flags = fcntl(signal_pipe[1], F_GETFL);
  if(fd_flags == -1)
    {
      perror("read descriptor flags");
      exit(1);
    }
  if(fcntl(signal_pipe[1], F_SETFL, fd_flags | O_NONBLOCK) == -1)
    {
      perror("write descriptor flags");
      exit(1);
    }


  /* convert the reading end of the pipe into a GIOChannel */
  GIOChannel* g_signal_in = g_io_channel_unix_new(signal_pipe[0]);

  /* 
   * we only read raw binary data from the pipe, 
   * therefore clear any encoding on the channel
   */
  g_io_channel_set_encoding(g_signal_in, NULL, &error);
  if(error != NULL){		/* handle potential errors */
    g_error("g_io_channel_set_encoding failed %s\n",
	    error->message);
    exit(1);
  }

  /* put the reading end also into non-blocking mode */
  g_io_channel_set_flags(g_signal_in,     
      g_io_channel_get_flags(g_signal_in) | G_IO_FLAG_NONBLOCK, &error);

  if(error != NULL){		/* tread errors */
    g_error("g_io_set_flags failed %s\n",
	    error->message);
    exit(1);
  }

  /* register the reading end with the event loop */
  g_io_add_watch(g_signal_in, G_IO_IN | G_IO_PRI, deliver_signal, NULL);

}
