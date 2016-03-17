#include <stdio.h>
#include <string.h> // strstr

#define DELIMITER ": "

int main(int argc, char *argv[])
{
  char* line = NULL;
  size_t space = 0;
  ssize_t read;
  while((read = getline(&line, &space, stdin)) != -1) {
	char* colon = strstr(line,DELIMITER);
	if(colon == NULL) {
	  printf("Warning: bad line %s\n",line);
	}
	fputs("\"",stdout);
	char* value = colon + sizeof(DELIMITER)-1;
	ssize_t len = strlen(value);
	if(len == 0) continue;
	while( value[len-1] == '\n' ) --len;
	fwrite(value,len,1,stdout);
	fputs(" AS \\\"",stdout);
	fwrite(line,colon-line,1,stdout);
	fputs("\\\", \"\n",stdout);
  }	
  return 0;
}
/*
Artist: artists.name
Album: albums.title
Duration: recordings.duration
Rating: (SELECT connections.strength FROM connections WHERE connections.blue = songs.id AND connections.red = (select id from mode)) AS Rating
Last Played: songs.played
*/
