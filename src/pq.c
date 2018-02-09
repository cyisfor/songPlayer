#include "pq.h"
#include "config.h"

#include <fcntl.h>
#include <string.h>
#include <assert.h>
#include <malloc.h>
#include <stdlib.h>
#include <unistd.h> // sleep

__thread PGconn* PQconn = NULL;
const char* pq_application_name = "songplayer?";

void PQinit(void) {
  /*const char* keywords[] = {"user",NULL};
  const char* values[] = {"music",NULL};
  */
  const char* keywords[] = {"user","dbname",
							"application_name",NULL};
  const char* values[] = {"music","music",
						  pq_application_name,NULL};
  PQconn = PQconnectdbParams(keywords,values, 0);
  assert(PQconn);
}
void PQassert_p(PGresult* result, int test, const char* tests, const char* file, int line) {
  if(!test) {
    fprintf(stderr,"%s:%d\n",file,line);
    fprintf(stderr,"PQ error %s %s\n%s %s\n%s\n%s",
            tests,
            PQerrorMessage(PQconn),
            PQresStatus(PQresultStatus(result)),PQresultErrorMessage(result),
            PQresultErrorField(result,PG_DIAG_MESSAGE_DETAIL),
            PQresultErrorField(result,PG_DIAG_MESSAGE_HINT));
    abort();
  }
}

void PQbegin(void) {
    PQcheckClear(PQexecParams(PQconn,"BEGIN",0,NULL,NULL,NULL,NULL,0));
}
void PQcommit(void) {
    PQcheckClear(PQexecParams(PQconn,"COMMIT",0,NULL,NULL,NULL,NULL,0));
}

void PQcheckClear(PGresult* r) {
    PQassert(r,
             r && ( PQresultStatus(r)==PGRES_COMMAND_OK ||
                    PQresultStatus(r)==PGRES_TUPLES_OK));
    PQclear(r);
}


bool pq_needed_reset(void) {
	if(PQstatus(PQconn) == CONNECTION_OK) return false;
	do {
		PQreset(PQconn);
		sleep(1);
	} while(PQstatus(PQconn) != CONNECTION_OK);
	return true;
}

#ifdef DEBUG_STATEMENTS
FILE* stmtLog = NULL;
int i,j;

PGresult *logExecPrepared(PGconn *conn,
                         const char *stmtName,
                         int nParams,
                         const char * const *paramValues,
                         const int *paramLengths,
                         const int *paramFormats,
                         int resultFormat) {
    PGresult* res = PQexecPrepared(conn,stmtName,nParams,paramValues,paramLengths,paramFormats,resultFormat);
    if(stmtLog == NULL) {
        stmtLog = fopen("/home/user/.local/songpicker-statements.log","ab");
    }
    fwrite(stmtName,strlen(stmtName),1,stmtLog);
    fprintf(stmtLog,"\1%d",nParams);
    fputc('\2',stmtLog);
    for(i=0;i<nParams;++i) {
        fputc('\3',stmtLog);
        if(paramFormats && paramFormats[i] != 0) {
            fwrite("<binary>",8,1,stmtLog);
        } else {
#define min(a,b) ((a) < (b) ? (a) : (b))
            fwrite(paramValues[i],paramLengths[i],1,stmtLog);
        }
    }
    fputc('\1',stmtLog);
    ExecStatusType status = PQresultStatus(res);
    const char* sstatus = PQresStatus(status);
    if(status==PGRES_TUPLES_OK) 
        fwrite("OK",2,1,stmtLog);
    else
        fwrite(sstatus,strlen(sstatus),1,stmtLog);
    fputc('\2',stmtLog);
    switch(status) {
        case PGRES_TUPLES_OK:
            if(resultFormat == 0) {                    
                int rows = PQntuples(res);
                int columns = PQnfields(res);
                for(i=0;i<rows;++i) {
                    fputc('\3',stmtLog);
                    for(j=0;j<columns;++j) {
                        fputc('\4',stmtLog);
                        char* value = PQgetvalue(res,i,j);
                        ssize_t len = strlen(value);
                        fwrite(value,min(len,4),1,stmtLog);
                    }
                }
            }
            break;
        case PGRES_NONFATAL_ERROR:
        case PGRES_FATAL_ERROR:
        case PGRES_BAD_RESPONSE:
            {
            char* message = PQresultErrorMessage(res);
            fwrite(message,strlen(message),1,stmtLog);
            fputc('\3',stmtLog);
            message = PQresultErrorField(res,PG_DIAG_MESSAGE_PRIMARY);
            if(message)
                fwrite(message,strlen(message),1,stmtLog);
            fputc('\3',stmtLog);
            message = PQresultErrorField(res,PG_DIAG_MESSAGE_DETAIL);
            if(message)
                fwrite(message,strlen(message),1,stmtLog);
            fputc('\3',stmtLog);
            message = PQresultErrorField(res,PG_DIAG_MESSAGE_HINT);
            if(message)
                fwrite(message,strlen(message),1,stmtLog);
            fputc('\3',stmtLog);
            message = PQresultErrorField(res,PG_DIAG_SOURCE_FUNCTION);
            if(message)
                fwrite(message,strlen(message),1,stmtLog);

            fputc('\3',stmtLog);
            message = PQresultErrorField(res,PG_DIAG_INTERNAL_POSITION);
            if(message)
                fwrite(message,strlen(message),1,stmtLog);

            fputc('\3',stmtLog);
            message = PQresultErrorField(res,PG_DIAG_INTERNAL_QUERY);
            if(message)
                fwrite(message,strlen(message),1,stmtLog);

            fputc('\3',stmtLog);
            message = PQresultErrorField(res,PG_DIAG_CONTEXT);
            if(message)
                fwrite(message,strlen(message),1,stmtLog);
            }
            break;
        default:
            break;
    };

    fputc('\n',stmtLog);
    fflush(stmtLog);
    return res;
}
#endif
