#include <libuv.h>

#include "nextreactor.h"


#define CHECK(status, msg)											\
  if (status != 0) {																			 \
    fprintf(stderr, "%s: %s\n", msg, uv_err_name(status)); \
    exit(1);																							 \
  }

GHashTable* clients = NULL;

uv_buf_t latest_song[] = {
	{}, // host://site/prefix/
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

// meh, recursive dependencies because late starting!
void on_connect(uv_stream_t* server_handle, int status);

void broadcast_song(uv_tcp_t* server) {
	PGresult* current_song =
		logExecPrepared(PQconn,"getTopSongPath",
										0,NULL,NULL,NULL,0);
	if(PQntuples(current_song) == 0) {
		PQcheckClear(current_song);
		return;
	}

	latest_song[1].len = PQgetlength(current_song,0,0);
	latest_song[1].base = g_strndup(PQgetvalue(current_song,0,0),
																	latest_song[1].len);
	PQcheckClear(current_song);
	// be sure clients is clear, before iterating through it
	// in case uv_write immediately calls the callback
	// (it doesn't, but just in case)
	GHashTable* in_use = clients;
	clients = g_hash_table_new(g_pointer_hash,
															 g_pointer_equal);
	if(in_use == NULL) {
		// just starting up
		// okay, we got our first song, so start listening
		r = uv_tcp_bind(&server, 0x1000, on_connect);
		CHECK(r,"tcp_bind");
	} else {
		g_hash_table_foreach(in_use,
												 // sorcery, the key is the first arg
												 // so don't care about arg 2, and 3
												 write_latest,
												 NULL);
		g_hash_table_destroy(in_use);
	}
}



void after_write(uv_write_t* req, int status) {
	CHECK(status, "write");
	if(uv_is_closing((uv_handle_t*)req->handle))
		return;
	struct client* client = (struct client*)req->handle->data;
	// we never even listen before there's a valid song to write
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

#define PORT 7892
#define S(derp) #derp

int main(int argc, char** argv) {
	assert(argc == 2);
	const char* format;
	const char* host = getenv("host");
	const char* prefix = getenv("prefix");
	if(getenv("prefix")) {
		format = "http://%s:" S(PORT) "/%s/";
	} else {
		format = "http://%s:" S(PORT) "/";
	}
	latest_song[0].len = g_snprintf(NULL,0,
																	 format,
																	 host,prefix);
	latest_song[0].data = g_malloc(latest_song[0].len);
	g_snprintf(latest_song[0].data,latest_song[0].len,
						 format,
						 host,prefix);

	preparation_t query[] = {
    {
      "getTopSongPath",
			"SELECT recordings.path FROM queue"
			"INNER JOIN recordings ON recordings.id = queue.recording"
			"ORDER BY queue.id ASC LIMIT 1"
		}
	}

	PQinit();
	prepareQueries(query);
	
	uv_tcp_t server;
	int r = uv_tcp_init(uv_default_loop(), &server);
	CHECK(r,"tcp_init");
	r = uv_tcp_keepalive(&server,1,60);
	CHECK(r,"tcp_keepalive");
	struct sockaddr_in6 address;
	r = uv_ip6_addr(getenv("address"), PORT,&address);
	CHECK(r,"ip6_addr");
	onNext((void*)send_song,&server);
}
