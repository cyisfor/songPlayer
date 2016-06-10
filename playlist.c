#include "nextreactor.h"
#include "pq.h"
#include "preparation.h"

#include <uv.h>
#include <glib.h>
#include <stdlib.h> // exit
#include <string.h>

#include <assert.h>

struct client {
	uv_write_t write_req;
	uv_tcp_t handle;
	GByteArray* buffer;
	uv_buf_t buf;
};

#define PORT 7892
#define SPORT "7892" // sigh...

#define CHECK(status, msg)											\
  if (status != 0) {																			 \
    fprintf(stderr, "%s: %s\n", msg, uv_err_name(status)); \
    exit(1);																							 \
  }

GHashTable* clients = NULL;

uv_buf_t latest_song[] = {
	{LIT("#EXTINF:")},
	{}, // track duration
	{LIT(", ")}
	{}, // track title
	{LIT("\r\n")},
	{}, // host://site/prefix/
	{}, // filename
	{"\r\n",2}
};

enum { DURATION = 1, TITLE = 3, PREFIX = 5, FILENAME = 6 } ;

void on_closed(uv_handle_t* handle) {
	struct client* client = (struct client*)handle->data;
	g_hash_table_remove(clients,client);
	g_byte_array_free(client->buffer,TRUE);
	g_free(client->buf.base);
	g_free(client);
}

void listen_for_more(uv_write_t* req, int status) {
	CHECK(status, "write");
	if(uv_is_closing((uv_handle_t*)req->handle))
		return;
	struct client* client = (struct client*)req->handle->data;
	if(FALSE==g_hash_table_insert(clients,client,client)) {
		fprintf(stderr,"Warning: already had client in clients?\n");
	}
}

void write_latest(struct client* client) {
	uv_write(&client->write_req,
					 (uv_stream_t*)&client->handle,
					 latest_song,
					 sizeof(latest_song)/sizeof(uv_buf_t),
					 listen_for_more);
}

void get_latest_song() {
	PGresult* current_song =
		logExecPrepared(PQconn,"getTopSongPath",
										0,NULL,NULL,NULL,0);
	if(PQntuples(current_song) == 0) {
		PQcheckClear(current_song);
		return;
	}

	g_free(latest_song[DURATION].base);
	g_free(latest_song[TITLE].base);
	g_free(latest_song[FILENAME].base);
	
#define COPY_OVER(dest, src)																				\
		latest_song[dest].len = PQgetlength(current_song,0,src);				\
		latest_song[dest].base = g_malloc(latest_song[dest].len);				\
		strncpy(latest_song[dest].base,PQgetvalue(current_song,0,src),	\
						latest_song[dest].len);
	COPY_OVER(DURATION,1);
	COPY_OVER(TITLE, 2);
#undef COPY_OVER
	
	char* path = PQgetvalue(current_song,0,0);
char* base = strrchr(path,'/');
	if(base == NULL)
		base = g_uri_escape_string(path,NULL,FALSE);
	else
		base = g_uri_escape_string(base+1,NULL,FALSE);
	latest_song[FILENAME].base = base;
	latest_song[FILENAME].len = strlen(base);
	PQcheckClear(current_song);
}

void broadcast_song(uv_tcp_t* server) {
	get_latest_song();
	// be sure clients is clear, before iterating through it
	// in case uv_write immediately calls the callback
	// (it doesn't, but just in case)
	GHashTable* in_use = clients;
	clients = g_hash_table_new(g_direct_hash,
															 g_direct_equal);

	if(in_use != NULL) {
		g_hash_table_foreach(in_use,
												 // sorcery, the key is the first arg
												 // so don't care about arg 2, and 3
												 (void*)write_latest,
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

#define LIT(s) s, (sizeof(s)-1)

const uv_buf_t http_start = {
	.base =
	LIT("HTTP/1.0 200 OK\r\n"
			"Content-Type: audio/mpegurl\r\n"
			"\r\n"
			"#EXTM3U\r\n\r\n")
};

void on_read(uv_stream_t* handle, ssize_t nread, const uv_buf_t * buf) {
	if(nread < 0) {
		if(nread != UV_EOF) {
			fprintf(stderr,"oops: %d:%s\n",nread,uv_err_name(nread));
		}
		uv_close((uv_handle_t*)handle, on_closed);
		return;
	}
	struct client* client = (struct client*)handle->data;
	g_byte_array_append(client->buffer, buf->base, nread);
	guint8* where = strstr(client->buffer->data,"\r\n\r\n");
	// wow is this cheap
	if(where == NULL) return;
	g_byte_array_remove_range(client->buffer,
														0,
														where-client->buffer->data);
	int r = uv_write(&client->write_req,
									 handle,
									 &http_start,
									 1,
									 after_write);
}


void alloc(uv_handle_t* handle, size_t suggested, uv_buf_t* buf) {
	struct client* client = (struct client*)handle->data;
	if(client->buf.base == NULL) {
		client->buf.base = g_malloc(suggested);
		client->buf.len = suggested;
	}
	buf->base = client->buf.base;
	buf->len = client->buf.len;
}

void on_connect(uv_stream_t* server_handle, int status) {
	CHECK(status,"connect");
	struct client* client = g_new0(struct client,1);
	uv_tcp_init(uv_default_loop(),&client->handle);
	client->handle.data = client;
	client->buffer = g_byte_array_new();
	int r = uv_accept(server_handle,(uv_stream_t*)&client->handle);
	CHECK(r,"accept");
	uv_read_start((uv_stream_t*)&client->handle, alloc, on_read);
}

int main(int argc, char** argv) {
	const char* format;
	const char* host = getenv("host");
	assert(host);
	const char* prefix = getenv("prefix");
	if(getenv("prefix")) {
		format = "http://[%s]/%s/";
	} else {
		format = "http://[%s]/";
	}
	latest_song[PREFIX].len = g_snprintf(NULL,0,
																			 format,
																			 host,prefix)+1;
	latest_song[PREFIX].base = g_malloc(latest_song[PREFIX].len);
	g_snprintf(latest_song[PREFIX].base,latest_song[PREFIX].len,
						 format,
						 host,prefix);
	preparation_t query[] = {
    {
      "getTopSongPath",
			"SELECT recordings.path, recordings.duration, song.title FROM queue\n"
			"INNER JOIN recordings ON recordings.id = queue.recording\n"
			"INNER JOIN songs ON songs.id = queue.song\n"
			"ORDER BY queue.id ASC LIMIT 1"
		}
	};

	PQinit();
	prepareQueries(query);

	clients = g_hash_table_new(g_direct_hash,
														 g_direct_equal);

	uv_tcp_t server;
	int r = uv_tcp_init(uv_default_loop(), &server);
	CHECK(r,"tcp_init");
	r = uv_tcp_keepalive(&server,1,60);
	CHECK(r,"tcp_keepalive");

	// okay, we got our first song, so start listening
	get_latest_song();
	struct sockaddr_in6 address;
	r = uv_ip6_addr(host, PORT, &address);
	CHECK(r,"ip6_addr");
	r = uv_tcp_bind(&server,
									(const struct sockaddr*)&address,
									0);
	CHECK(r,"tcp_bind");
	r = uv_listen((uv_stream_t*)&server,0x1000, on_connect);
	CHECK(r,"listen");

	onNext((void*)broadcast_song,&server);
}
