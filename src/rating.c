#include "rating.h"
#include "pq.h"

void do_rating(const char* rating) {
	const char* values[] = { rating };
	const int lengths[] = { strlen(rating) };
	const int fmt[] = { 0 };
	PQclear(PQexecParams(PQconn,"SELECT connectionStrength(id, \n"
						 "(SELECT song FROM recordings WHERE id = (\n"
						 "SELECT recording from queue order by id limit 1)), "
						 "$1) FROM mode",
						 1,NULL,values,lengths,fmt,0));
}
