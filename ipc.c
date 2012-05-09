#include "ipc.h"
#include "config.h"

#include <sys/socket.h>
#include <sys/un.h>

int IPCbind(const char* id) {
  struct sockaddr_un where;
  const slice derp = configAt(id);
  where.sun_family = AF_UNIX;
  memcpy(where.sun_path,derp.data,derp.end+1);
  
  int sock = socket(AF_UNIX,SOCK_DGRAM,0);

  if(0==bind(sock,(struct sockaddr*)&where,sizeof(where)))
    return sock;
  perror("Bind failed!");
  exit(23);
}

void IPCsend(const char* id, slice what) {
  struct sockaddr_un where;
  const slice derp = configAt(id);
  where.sun_family = AF_UNIX;
  memcpy(where.sun_path,derp.data,derp.end+1);
  
  int sock = socket(AF_UNIX,SOCK_DGRAM,0);
  
  sendto(sock,what.data,what.end-what.start,0,(struct sockaddr*)&where,sizeof(where));
  close(sock);
}

slice IPCrecv(int sock) {
  const char data[0x1000];
  ssize_t amt = recv(sock,data,0x1000,0);
  if(amt<0) {
    perror("Recv failed!");
    exit(23);
  }
  slice out = { data, 0, amt};
  return out;
}
