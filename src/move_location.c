#include "preparation.h"
#include "pq.h"

#include <string.h> // memcpy
#include <unistd.h> // fsync, 
#include <sys/sendfile.h>
#include <stdio.h> // rename???
#include <fcntl.h> // open, O_*
#include <stdlib.h> // abort
#include <assert.h>
#include <errno.h>

#define ensure(a) if(!(a)) { perror("ensure faildeded " #a); abort(); }

int main(int argc, char *argv[])
{
	if(argc != 3) exit(1);

	const char* src = argv[1];
	const char* dest = argv[2];
	int srclen = strlen(src);
	int destlen = strlen(dest);
	char like[srclen + 2];
	memcpy(like,src,srclen);
	like[srclen] = '%';
	like[srclen+1] = 0;
	preparation find = prepare(
			"SELECT id, path FROM recordings "
			"WHERE encode(path,'escape') LIKE $1::text LIMIT 500");
	preparation update = prepare(
			"UPDATE recordings SET path = $2 WHERE id = $1");
	preparation begin = prepare("BEGIN");
	preparation commit = prepare("COMMIT");

			
	const char* values[] = { like };
	const int lengths[] = { srclen+1 };
	const int fmt[] = { 0 };
		
	for(;;) {
		
		PGresult* result = prepare_exec(find, 1,
																	values,
																	lengths,
																	fmt,
																	1);
		PQassert(result,result && PQresultStatus(result)==PGRES_TUPLES_OK);

		int i;
		int numrows = PQntuples(result);
		if(numrows == 0) break;
		for(i=0;i<numrows;++i) {
		const char* srcpath = PQgetvalue(result,i,1);
		assert(srcpath);
		assert(0==memcmp(srcpath, src, srclen));
		srcpath += srclen;
		int restlen = PQgetlength(result,i,1) - srclen;
		char destpath[destlen + restlen + 1];
		memcpy(destpath,dest,destlen);
		memcpy(destpath+destlen,srcpath,restlen);

		{
			const char* v2[] = { PQgetvalue(result,i,0), destpath };
			const int l2[] = { PQgetlength(result,i,0), destlen+restlen };
			const int fmt[] = { 1, 1 };

			PQclear(prepare_exec(begin, 0, NULL, NULL, NULL, 0));
		
			PQclear(prepare_exec(update, 2, v2, l2, fmt, 1));
		}

		if(0 != rename(srcpath, destpath)) {
			if(errno == EXDEV) {
				int inp = open(srcpath,O_RDONLY);
				assert(inp >= 0);
				int out = open(destpath, O_WRONLY | O_CREAT, 0644);
				assert(out >= 0);
				for(;;) {
					ssize_t amt = sendfile(out, inp, NULL, 0x10000);
					if(amt == 0) break;
					if(amt < 0) {
						perror("huh?");
						exit(2);
					}
				}
				ensure(0==fsync(out));
				ensure(0==close(out));
				ensure(0==close(inp));
			} else {
				perror("washt");
				exit(3);
			}
		}

		PQclear(prepare_exec(commit, 0, NULL, NULL, NULL, 0));		
		
	}
	
	return 0;
}
