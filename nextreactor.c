#include "pq.h"
#include <uv.h>
#include <stdlib.h>
#include <assert.h>

struct context {
  const char* name;
  void* udata;
  void (*next)(void*);
};

static void fakealloc(uv_handle_t* handle, size_t suggested, uv_buf_t* buf) {
  // fuck tha police
  return;
}

static void reopen(uv_tcp_t* tcp);

static void getsome(uv_stream_t* stream, ssize_t nread, const uv_buf_t* nothing) {
  if(nread == UV_EOF) {
    //PQclose(PQconn);
    reopen((uv_tcp_t*) stream);
    return;
  }
  if(nread == UV_EFAULT) {
    return;
  }
  if(nread != UV_ENOBUFS) {
    perror(uv_strerror(nread));
    exit(23);
  }
  
  PQconsumeInput(PQconn);
  
  PGnotify   *notify;

  struct context* ctx = (struct context*) stream->data;
  
  while ((notify = PQnotifies(PQconn)) != NULL)
    {
      if(0==strcmp(notify->relname,ctx->name)) {
        ctx->next(ctx->udata);
      }
      PQfreemem(notify);
    }
}

static void reopen(uv_tcp_t* tcp) {
  int sock = PQsocket(PQconn);
  assert(sock>=0);
  assert(0==uv_tcp_init(uv_default_loop(), tcp));
  assert(0==uv_tcp_open(tcp, sock));  
  uv_read_start((uv_stream_t*)tcp, fakealloc, getsome);
}

void onNext(void (*next)(void*), void* udata) {
  PQcheckClear(PQexec(PQconn,"LISTEN next"));

  uv_tcp_t* tcp = (uv_tcp_t*)
    malloc(sizeof(uv_tcp_t) + sizeof(struct context));
  struct context* ctx = (struct context*) ((void*)tcp) + sizeof(uv_tcp_t);
  tcp->data = ctx;    
  ctx->next = next;
  ctx->udata = udata;
  ctx->name = "next";  
  reopen(tcp);
  
  uv_run(uv_default_loop(),UV_RUN_DEFAULT);
  exit(-1);
}
