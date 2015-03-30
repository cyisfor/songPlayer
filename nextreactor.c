#include "pq.h"

#include <uv.h>

struct context {
  const char* name;
  void (*next)(void);
};

static void fakealloc(uv_handle_t* handle, size_t suggested, uv_buf_t* buf) {
  // fuck tha police
  return;
}

static void reopen(uv_tcp_t* tcp);

static void getsome(uv_stream_t* stream, ssize_t nread, const uv_buf_t* nothing) {
  if(nread == UV_EOF) {
    PQclose(PQconn);
    reopen((uv_tcp_t*) stream);
    return;
  }
  assert(nread == UV_ENOBUFS);
  
  PQconsumeInput(PQconn);
  
  PGnotify   *notify;

  struct context* ctx = (struct context*) stream->data;
  
  while ((notify = PQnotifies(PQconn)) != NULL)
    {
      if(0==strcmp(notify->relname,ctx->name)) {
        ctx->next();
      }
      PQfreemem(notify);
    }
}

static void reopen(uv_tcp_t* tcp) {
  int sock = PQsocket(PQconn);
  assert(sock>=0);
  assert(0==uv_tcp_init(uv_default_loop(), tcp));
  assert(0==uv_tcp_open(tcp, sock));  
  uv_read_start(tcp, fakealloc, getsome);
}

void onNext(void (*next)(void)) {
  PQcheckClear(PQexec(PQconn,"LISTEN next"));

  uv_tcp_t* tcp = (uv_tcp_t*)
    malloc(sizeof(struct uv_tcp_t) + sizeof(struct context));
  struct context* ctx = tcp + sizeof(uv_tcp_t);
  tcp->data = ctx;    
  ctx->next = next;
  ctx->name = "next";  
  reopen(tcp);
  
  uv_run(uv_default_loop(),UV_RUN_DEFAULT);
  exit(-1);
}
