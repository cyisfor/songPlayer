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
#define LIT(s) s, (sizeof(s)-1)

// can cache this between songs
// but update the uv_buf_t len, not this!
#define SONGS_PLAYED_DERP 0x100
gchar songs_played_buf[SONGS_PLAYED_DERP];

gint songs_played = 0;

uv_buf_t http_session[] = {
	{LIT("HTTP/1.0 200 OK\r\n"
			"Content-Type: application/vnd.apple.mpegurl\r\n"
			"\r\n"
			"#EXTM3U\r\n\r\n")},
	{LIT("#EXTINF:")},
	{}, // track duration
	{LIT(", ")},
	{}, // track title
	{LIT("\r\n")},
	{}, // host://site/prefix/
	{}, // filename
	{LIT("\r\n\r\n")},
	{}, // host://site:port/
	{songs_played_buf,0}, // "%x" printf songs_played counter
	{LIT("\r\n")}
};

enum { DURATION = 2,
			 TITLE = 4,
			 PREFIX = 6,
			 FILENAME = 7,
			 PLAYLIST_URI = 9,
			 SONGS_PLAYED = 0xa
};

GPtrArray* waiters = NULL;



void on_closed(uv_handle_t* handle) {
	struct client* client = (struct client*)handle->data;
	g_ptr_array_remove(waiters,client);
	g_byte_array_free(client->buffer,TRUE);
	g_free(client->buf.base);
	g_free(client);
}

void close_stuff(uv_write_t* req, int status) {
	CHECK(status, "write");
	if(uv_is_closing((uv_handle_t*)req->handle))
		return;
	uv_close((uv_handle_t*)req->handle, on_closed);
}

void send_playlist(struct client* client) {
	uv_write(&client->write_req,
					 (uv_stream_t*)&client->handle,
					 http_session,
					 sizeof(http_session)/sizeof(http_session[0]),
					 close_stuff);
}

void get_latest_song() {
	PGresult* current_song =
		logExecPrepared(PQconn,"getTopSongPath",
										0,NULL,NULL,NULL,0);
	if(PQntuples(current_song) == 0) {
		PQcheckClear(current_song);
		return;
	}

#define COPY_OVER(dest, src)																				\
		http_session[dest].len = PQgetlength(current_song,0,src);				\
		http_session[dest].base = g_realloc(http_session[dest].base,			\
																			 http_session[dest].len);			\
		strncpy(http_session[dest].base,PQgetvalue(current_song,0,src),	\
						http_session[dest].len);
	COPY_OVER(DURATION,1);
	COPY_OVER(TITLE, 2);
#undef COPY_OVER

	g_free(http_session[FILENAME].base);
	char* path = PQgetvalue(current_song,0,0);
	char* base = strrchr(path,'/');
	if(base == NULL)
		base = g_uri_escape_string(path,NULL,FALSE);
	else
		base = g_uri_escape_string(base+1,NULL,FALSE);
	http_session[FILENAME].base = base;
	http_session[FILENAME].len = strlen(base);
	PQcheckClear(current_song);

	http_session[SONGS_PLAYED].len =
		snprintf(http_session[SONGS_PLAYED].base,
						 SONGS_PLAYED_DERP,"%x",

						 ++songs_played);
}

void broadcast_song(uv_tcp_t* server) {	
	get_latest_song();

	// sorcery, the client is the first arg
	// so don't care about arg 2
	g_ptr_array_foreach(waiters,(void*)send_playlist,NULL);
	
	// clear out these waiters, since they were un-stalled
	g_ptr_array_remove_range(waiters,0,waiters->len);
}

void on_read(uv_stream_t* handle, ssize_t nread, const uv_buf_t * buf) {
	if(nread < 0) {
		if(nread != UV_EOF) {
			fprintf(stderr,"oops: %ld:%s\n",nread,uv_err_name(nread));
		}
		uv_close((uv_handle_t*)handle, on_closed);
		return;
	}
	struct client* client = (struct client*)handle->data;
	g_byte_array_append(client->buffer, (const guint8*)buf->base, nread);
	guint8* where = strstr(client->buffer->data,"\r\n\r\n");
	// wow is this cheap
	if(where == NULL) return;
	guint8* slastid = strstr((const char*)client->buffer->data,"GET /");
	if(slastid == NULL) {
		uv_close((uv_handle_t*)handle,on_closed);
		return;
	}
	slastid += sizeof("GET /")-1;
	gint lastid = strtol(slastid,NULL,0x10);
	printf("lastid %x %s\n",lastid,slastid);
	// we're done with the headers, so remove
	g_byte_array_remove_range(client->buffer,
															0,
															where-client->buffer->data);
		
	if(lastid == songs_played) {
		// whoops, they already have this one.
		// stall the connection until we get a new song.
		g_ptr_array_add(waiters,client);
		return;
	}
	// the id is different, so send the playlist and don't wait.

	send_playlist(client);
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

	#define DOPRINTF(what, ...) http_session[what].len = g_snprintf \
			(NULL,0,																									 \
			 format,																									 \
			 __VA_ARGS__)+1;																						 \
	http_session[what].base = g_malloc(http_session[what].len);			 \
	g_snprintf(http_session[what].base,http_session[what].len,			 \
						 format,																						 \
						 __VA_ARGS__);

	if(getenv("prefix")) {
		format = "http://[%s]/%s/";
		DOPRINTF(PREFIX,host,getenv("prefix"));
	} else {
		format = "http://[%s]/";
		DOPRINTF(PREFIX,host);
	}

	format = "http://[%s]:%d/";
	DOPRINTF(PLAYLIST_URI,host,PORT);

	preparation_t query[] = {
    {
      "getTopSongPath",
			"SELECT recordings.path,\n"
			"  recordings.duration / 1000000000,\n"
			"  songs.title\n"
			"FROM queue\n"
			"INNER JOIN recordings ON recordings.id = queue.recording\n"
			"INNER JOIN songs ON songs.id = recordings.song\n"
			"ORDER BY queue.id ASC LIMIT 1"
		}
	};

	PQinit();
	prepareQueries(query);

	waiters = g_ptr_array_sized_new(5);

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
