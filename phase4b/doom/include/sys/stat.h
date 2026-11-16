#include <sys/types.h>
struct stat {off_t st_size;unsigned int st_mode;};
#define S_IFDIR 0040000
#define S_ISDIR(m) ((m)&S_IFDIR)
int stat(const char *,struct stat *);int mkdir(const char *,unsigned int);
