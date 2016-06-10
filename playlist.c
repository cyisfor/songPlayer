#include <libuv.h>

#include "nextreactor.h"


#define CHECK(status, msg)											\
  if (status != 0) {																			 \
    fprintf(stderr, "%s: %s\n", msg, uv_err_name(status)); \
    exit(1);																							 \
  }

GHashTable* clients = NULL;

uv_buf_t latest_song[] = {
	{"host://",sizeof("host://")-1}
	{}, // site
	{}, // /prefix/
	{}, // filename
	{"\r\n",2}
};

void listen_for_more(uv_write_t* req, int status) {
	CHECK(status, "write");
	if(uv_is_closing((uv_handle_t*)req->handle))
		return;
	struct client* client = (struct client*)req->handle->data;
	assert(TRUE==g_hash_table_insert(clients,client,client));
}

void write_latest(struct client* client) {
	uv_write(&client->write_req,
					 (uv_stream_t*)&client->handle,
					 latest_song,
					 sizeof(latest_song)/sizeof(uv_buf_t),
					 listen_for_more);
}

void broadcast_song(uv_tcp_t* server) {
	if(latest_song[1].base == NULL) {
		// okay, load up a song, and start listening
		r = uv_tcp_bind(&server, 0x1000, on_connect);
		CHECK(r,"tcp_bind");




void after_write(uv_write_t* req, int status) {
	CHECK(status, "write");
	if(uv_is_closing((uv_handle_t*)req->handle))
		return;
	struct client* client = (struct client*)req->handle->data;
	write_latest(client);
}

void on_read(uv_stream_t* handle, ssize_t nread, const uv_buf_t * buf) {
	struct client* client = (struct client*)handle->data;
	client->buffer = g_byte_array_append(client->buffer, data, nread);
	char* where = strcmp(client->buffer->data,"\r\n\r\n");
	// wow is this cheap
	if(where == NULL) return;
	client->buffer = g_byte_array_remove_range(client->buffer,
																						 0,
																						 where-client->buffer->data);
	uv_buf_t response
		uv_buf_init("HTTP/1.0 200 OK\r\n"
								"Content-Type: audio/mpegurl\r\n"
								"\r\n");
														
	int r = uv_write(&client->write_req,
									 handle,
									 response,
									 1,
									 after_write);
}
		

void alloc(uv_handle_t* handle, size_t suggested, uv_buf_t* buf) {
	struct client* client = (struct client*)handle->data;
	if(client->buf.base == NULL) {
		*client->buf = uv_buf_init((char*)g_malloc(suggested), suggested);
	}
	*buf = *client->buf;
}

void on_connect(uv_stream_t* server_handle, int status) {
	CHECK(status,"connect");
	struct client* client = g_new(struct client,1);
	uv_tcp_init(uv_default_loop(),&client->handle);
	client->handle.data = client;
	int r = uv_accept(server_handle,(uv_stream_t*)&client->handle);
	CHECK(r,"accept");
	uv_read_start((uv_stream_t*)&client->handle, alloc, on_read);
}

int main(int argc, char** argv) {
	assert(argc == 2);
	const char* prefix = getenv("prefix");

	uv_tcp_t server;
	int r = uv_tcp_init(uv_default_loop(), &server);
	CHECK(r,"tcp_init");
	r = uv_tcp_keepalive(&server,1,60);
	CHECK(r,"tcp_keepalive");
	struct sockaddr_in6 address;
	r = uv_ip6_addr(getenv("address"), 8970,&address);
	CHECK(r,"ip6_addr");
	onNext((void*)send_song,&server);
}
