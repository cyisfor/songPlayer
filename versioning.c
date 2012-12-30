#include "pq.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

union commandData {
  const char* sql;
  const char* path;
  int (*generator)(void);
};

struct command {
  uint8_t type;
  union commandData data;
};

#define FROMFILE 0
#define TEXT 1
#define CODE 2
#define DONE 3

struct schema_version {
  uint64_t version;
  struct command commands[0x10];
};

#define endCommands { DONE, {}}

static int Checkclear(PGresult* result) {
  int test = PQresultStatus(result);
  if(test!=PGRES_TUPLES_OK && test != PGRES_COMMAND_OK)
    PQassert(result,0);
  PQclear(result);
  return test==PGRES_TUPLES_OK || test == PGRES_COMMAND_OK;
}

static void measureSingleTrackRecordings(void);

struct schema_version versions[] = {
  { 1,
    {
      { FROMFILE, { .path = "base.sql" }},
      endCommands}},
  { 2,
    {
      { FROMFILE, { .path = "selins.sql" }},
      endCommands}},
};

static int runCommand(struct command* command) {
  puts("Running command");
  switch(command->type) {
  case FROMFILE:
    {
      const char* path = command->data.path;
      printf("file: %s\n",path);
      FILE* fp = fopen(path,"rt");
      if(!fp) {
        fprintf(stderr,"Couldn't open %s\n",path);
        exit(23);
      }
      char statements[0x8000];
      size_t len = fread(statements,1,0x8000,fp);
      statements[len] = '\0';
      return Checkclear(PQexec(PQconn, statements));
    }
    break;
  case TEXT:
    {
      const char* statement = command->data.sql;
      printf("text: %s\n",statement);
      return Checkclear(PQexecParams(PQconn,statement,
                                     0,NULL,NULL,NULL,NULL,0));
    }
    break;
  case CODE:
    puts("code");
    return command->data.generator();
  }
}

int main(void) {
  PQinit();
  PQclear(PQexecParams(PQconn, "CREATE TABLE versions (version BIGINT)",
                       0,NULL,NULL,NULL,NULL,0));
  PGresult* result = PQexecParams(PQconn,"SELECT version FROM versions",
                                   0,NULL,NULL,NULL,NULL,0);
  uint64_t oldVersion = 0;
  if(PQntuples(result)>0) {
    oldVersion = strtoll(PQgetvalue(result,0,0),NULL,10);
  }

  int i;
  for(i=0;i<sizeof(versions)/sizeof(struct schema_version);++i) {
    struct schema_version* version = versions + i;
    if(version->version > oldVersion) {
      struct command* command = version->commands;
      for(;command;++command) {
        if(command->type==DONE) break;
        if(!runCommand(command)) goto SKIP;
      }
      oldVersion = version->version;
      Checkclear(PQexecParams(PQconn, "BEGIN",
                           0,NULL,NULL,NULL,NULL,0));
      Checkclear(PQexecParams(PQconn, "DELETE FROM versions",
                           0,NULL,NULL,NULL,NULL,0));
      char versionStr[0x400];
      const int fmt = 0;
      int len = snprintf(versionStr,0x400,"%lu",oldVersion);
      const char* values[] = { versionStr };
      Checkclear(PQexecParams(PQconn, "INSERT INTO versions (version) VALUES ($1)",
                           1,NULL,values,&len,&fmt,0));
      Checkclear(PQexecParams(PQconn, "COMMIT",
                           0,NULL,NULL,NULL,NULL,0));
    SKIP:
      0;
    }
  }
}
