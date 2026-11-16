#include <sys/types.h>
int access(const char *,int);int isatty(int);int getpid(void);int close(int);int read(int,void *,unsigned int);int write(int,const void *,unsigned int);
#define F_OK 0
#define R_OK 4
#define W_OK 2
