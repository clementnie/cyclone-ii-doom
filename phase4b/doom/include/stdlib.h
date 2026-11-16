#ifndef MINI_STDLIB
#define MINI_STDLIB
#include <stddef.h>
void *malloc(size_t);void free(void *);void *calloc(size_t,size_t);void *realloc(void *,size_t);
int abs(int);long labs(long);int atoi(const char *);long strtol(const char *,char **,int);unsigned long strtoul(const char *,char **,int);double atof(const char *);
char *getenv(const char *);int system(const char *);void exit(int) __attribute__((noreturn));void abort(void) __attribute__((noreturn));int atexit(void (*)(void));
void qsort(void *,size_t,size_t,int (*)(const void *,const void *));
#endif
