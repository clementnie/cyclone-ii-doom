#ifndef MINI_STDIO
#define MINI_STDIO
#include <stddef.h>
#include <stdarg.h>
typedef struct MiniFile FILE;extern FILE *stdin,*stdout,*stderr;
#define EOF (-1)
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
int printf(const char *,...);int fprintf(FILE *,const char *,...);int sprintf(char *,const char *,...);int snprintf(char *,size_t,const char *,...);int vsnprintf(char *,size_t,const char *,va_list);int vprintf(const char *,va_list);int vfprintf(FILE *,const char *,va_list);int vsprintf(char *,const char *,va_list);int sscanf(const char *,const char *,...);int fscanf(FILE *,const char *,...);
FILE *fopen(const char *,const char *);int fclose(FILE *);size_t fread(void *,size_t,size_t,FILE *);size_t fwrite(const void *,size_t,size_t,FILE *);int fseek(FILE *,long,int);long ftell(FILE *);int fflush(FILE *);int ferror(FILE *);int feof(FILE *);int fgetc(FILE *);int fputc(int,FILE *);char *fgets(char *,int,FILE *);int puts(const char *);int putchar(int);int remove(const char *);int rename(const char *,const char *);
#endif
