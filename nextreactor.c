#include "pq.h"
#include <uv.h>
#include <stdlib.h>
#include <assert.h>
#include <error.h>

struct context {
  const char* name;
  void* udata;
  void (*next)(void*);
};

static void fakealloc(uv_handle_t* handle, size_t suggested, uv_buf_t* buf) {
  // fuck tha police
  buf->len = 0;
  return;
}

static void reopen(uv_tcp_t* tcp, struct context* ctx);

static void getsome(uv_stream_t* stream, ssize_t nread, const uv_buf_t* nothing) {
  error(0,0,"UHH %p %p",stream,stream->data);
  if(nread == UV_EOF) {
    //PQclose(PQconn);
    error(0,EOF,"Connection lost.");
    uv_read_stop(stream);
    reopen((uv_tcp_t*) stream, (struct context*)stream->data);
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

static void reopen(uv_tcp_t* tcp, struct context* ctx) {
  int sock = PQsocket(PQconn);
  error(0,0,"New connection %x",sock);
  assert(sock>=0);
  assert(0==uv_tcp_init(uv_default_loop(), tcp));
  assert(0==uv_tcp_open(tcp, sock));
  tcp->data = ctx;
  uv_read_start((uv_stream_t*)tcp, fakealloc, getsome);
}

void onNext(void (*next)(void*), void* udata) {
  PQcheckClear(PQexec(PQconn,"LISTEN next"));

  void* data = malloc(sizeof(uv_tcp_t) + sizeof(struct context));
  uv_tcp_t* tcp = (uv_tcp_t*) data;    
  struct context* ctx = (struct context*) (data + sizeof(uv_tcp_t));
  ctx->next = next;
  ctx->udata = udata;
  ctx->name = "next";  
  reopen(tcp,ctx);
  
  error(uv_run(uv_default_loop(),UV_RUN_DEFAULT),0,"uv_run exited");
  exit(-1);
}
