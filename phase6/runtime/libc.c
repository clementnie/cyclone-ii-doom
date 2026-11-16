// SPDX-License-Identifier: GPL-2.0-or-later
// Bounded bare-metal runtime for this DOOM port; not a hosted POSIX libc.
#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
int errno;
void *memcpy(void *d,const void *s,size_t n){unsigned char *a=d;const unsigned char*b=s;while(n--)*a++=*b++;return d;}
void *memset(void*d,int v,size_t n){unsigned char*a=d;while(n--)*a++=v;return d;}
void *memmove(void*d,const void*s,size_t n){unsigned char*a=d;const unsigned char*b=s;if(a>b){while(n){--n;a[n]=b[n];}}else memcpy(d,s,n);return d;}
int memcmp(const void*a,const void*b,size_t n){const unsigned char*x=a,*y=b;while(n--){if(*x!=*y)return *x-*y;x++;y++;}return 0;}
size_t strlen(const char*s){size_t n=0;while(s[n])n++;return n;}
int strcmp(const char*a,const char*b){while(*a&&*a==*b){a++;b++;}return (unsigned char)*a-(unsigned char)*b;}
int strncmp(const char*a,const char*b,size_t n){while(n){if(*a!=*b||!*a)return (unsigned char)*a-(unsigned char)*b;a++;b++;n--;}return 0;}
char *strcpy(char*d,const char*s){char*r=d;while((*d++=*s++)){}return r;}
char *strncpy(char*d,const char*s,size_t n){size_t i=0;for(;i<n&&s[i];i++)d[i]=s[i];for(;i<n;i++)d[i]=0;return d;}
char *strchr(const char*s,int c){do{if(*s==(char)c)return (char*)s;}while(*s++);return NULL;}
char *strrchr(const char*s,int c){const char*r=NULL;do{if(*s==(char)c)r=s;}while(*s++);return (char*)r;}
char *strstr(const char*s,const char*t){size_t n=strlen(t);for(;*s;s++)if(!strncmp(s,t,n))return (char*)s;return n?NULL:(char*)s;}
int tolower(int c){return c>='A'&&c<='Z'?c+32:c;}
int toupper(int c){return c>='a'&&c<='z'?c-32:c;}
int isspace(int c){return c==' '||(c>=9&&c<=13);}
int strcasecmp(const char*a,const char*b){while(*a&&tolower(*a)==tolower(*b)){a++;b++;}return tolower((unsigned char)*a)-tolower((unsigned char)*b);}
int strncasecmp(const char*a,const char*b,size_t n){while(n--){int d=tolower((unsigned char)*a)-tolower((unsigned char)*b);if(d||!*a)return d;a++;b++;}return 0;}
int abs(int a){return a<0?-a:a;}
static int digit(int c){if(c>='0'&&c<='9')return c-'0';c=tolower(c);return c>='a'&&c<='z'?c-'a'+10:-1;}
static unsigned long number(const char*s,char**end,int base,int *negative){const char*orig=s;while(isspace(*s))s++;*negative=*s=='-';if(*s=='-'||*s=='+')s++;if((base==0||base==16)&&s[0]=='0'&&tolower(s[1])=='x'){base=16;s+=2;}if(!base)base=*s=='0'?8:10;const char*start=s;unsigned long v=0;int d;while((d=digit(*s))>=0&&d<base){v=v*base+d;s++;}if(end)*end=(char*)(s==start?orig:s);return v;}
long strtol(const char*s,char**end,int base){int neg;unsigned long v=number(s,end,base,&neg);return neg?(long)(0ul-v):(long)v;}
unsigned long strtoul(const char*s,char**end,int base){int neg;unsigned long v=number(s,end,base,&neg);return neg?0ul-v:v;}
int atoi(const char*s){return (int)strtol(s,NULL,10);}
double atof(const char*s){while(isspace(*s))s++;int neg=*s=='-';if(*s=='-'||*s=='+')s++;double v=0,scale=1;while(*s>='0'&&*s<='9')v=v*10+(*s++-'0');if(*s=='.'){s++;while(*s>='0'&&*s<='9'){scale*=0.1;v+=(*s++-'0')*scale;}}if(tolower(*s)=='e'){int e=atoi(s+1);if(e>308)e=308;if(e< -308)e=-308;while(e>0){v*=10;e--;}while(e<0){v*=0.1;e++;}}return neg?-v:v;}
double fabs(double d){union{double d;uint64_t u;}v={d};v.u&=UINT64_C(0x7fffffffffffffff);return v.d;}
// First-fit, split/coalescing allocator. Each returned pointer is 16-byte aligned.
typedef struct __attribute__((aligned(16))) Block {size_t size;struct Block*next;unsigned free;unsigned pad;} Block;
static Block *head;
volatile unsigned phase6_heap_high;
#ifndef PHASE5_TEST
extern unsigned char __heap_start[],__heap_end[];
#else
static union {long double align;unsigned char data[1024*1024];} test_heap;
#define __heap_start test_heap.data
#define __heap_end (test_heap.data+sizeof(test_heap.data))
#endif
void *malloc(size_t n){if(n>SIZE_MAX-15-sizeof(Block))return NULL;n=(n+15)&~(size_t)15;if(!n)n=16;
 if(!head){uintptr_t start=((uintptr_t)__heap_start+15)&~(uintptr_t)15;head=(Block*)start;head->size=(size_t)((uintptr_t)__heap_end-start)-sizeof(Block);head->next=NULL;head->free=1;}
 for(Block*b=head;b;b=b->next)if(b->free&&b->size>=n){if(b->size>=n+sizeof(Block)+16){Block*t=(Block*)((unsigned char*)(b+1)+n);t->size=b->size-n-sizeof(Block);t->next=b->next;t->free=1;b->next=t;b->size=n;}b->free=0;uintptr_t end=(uintptr_t)(b+1)+b->size; if(end>phase6_heap_high)phase6_heap_high=end;return b+1;}errno=12;return NULL;}
void free(void*p){if(!p)return;((Block*)p-1)->free=1;for(Block*b=head;b&&b->next;){if(b->free&&b->next->free){b->size+=sizeof(Block)+b->next->size;b->next=b->next->next;}else b=b->next;}}
void *calloc(size_t n,size_t m){if(m&&n>SIZE_MAX/m)return NULL;size_t bytes=n*m;void*p=malloc(bytes);if(p)memset(p,0,bytes);return p;}
void *realloc(void*p,size_t n){if(!p)return malloc(n);if(!n){free(p);return NULL;}Block*b=(Block*)p-1;if(n<=b->size)return p;void*q=malloc(n);if(q){memcpy(q,p,b->size);free(p);}return q;}
char *strdup(const char*s){size_t n=strlen(s)+1;char*d=malloc(n);if(d)memcpy(d,s,n);return d;}
// In-memory log ring: console output remains inspectable without new RTL.
volatile unsigned phase5_log_position;char phase5_log[4096];
int putchar(int c){phase5_log[phase5_log_position++&4095]=(char)c;return (unsigned char)c;}
int puts(const char*s){int n=0;while(*s){putchar(*s++);n++;}putchar('\n');return n+1;}
// snprintf: integer, pointer, string, character and fixed-decimal %f formats.
static void emit(char*b,size_t cap,size_t *n,char c){if(cap&&*n<cap-1)b[*n]=c;(*n)++;}
int vsnprintf(char*b,size_t cap,const char*f,va_list ap){size_t n=0;
 while(*f){if(*f!='%'){emit(b,cap,&n,*f++);continue;}f++;if(*f=='%'){emit(b,cap,&n,*f++);continue;}
 int left=0,zero=0,width=0,precision=-1,longs=0;while(*f=='-'||*f=='0'||*f=='+'||*f==' '||*f=='#'){if(*f=='-')left=1;if(*f=='0')zero=1;f++;}
 if(*f=='*'){width=va_arg(ap,int);f++;}else while(*f>='0'&&*f<='9')width=width*10+(*f++-'0');
 if(*f=='.'){precision=0;f++;if(*f=='*'){precision=va_arg(ap,int);f++;}else while(*f>='0'&&*f<='9')precision=precision*10+(*f++-'0');}
 while(*f=='l'||*f=='z'){longs+=*f=='z'?1:1;f++;}char c=*f?*f++:0;char temp[96];const char*s=temp;size_t len=0;int neg=0;
 if(c=='s'){s=va_arg(ap,const char*);if(!s)s="(null)";len=strlen(s);if(precision>=0&&len>(size_t)precision)len=precision;}
 else if(c=='c'){temp[len++]=(char)va_arg(ap,int);}
 else if(c=='d'||c=='i'||c=='u'||c=='x'||c=='X'||c=='o'||c=='p'){
  uint64_t v;unsigned base=(c=='x'||c=='X'||c=='p')?16:c=='o'?8:10;
  if(c=='p')v=(uintptr_t)va_arg(ap,void*);
  else if(c=='d'||c=='i'){int64_t a=longs>1?va_arg(ap,long long):longs?va_arg(ap,long):va_arg(ap,int);neg=a<0;v=neg?0-(uint64_t)a:(uint64_t)a;}
  else v=longs>1?va_arg(ap,unsigned long long):longs?va_arg(ap,unsigned long):va_arg(ap,unsigned);
  char rev[64];unsigned k=0;do{unsigned d=v%base;rev[k++]=d<10?'0'+d:(c=='X'?'A':'a')+d-10;v/=base;}while(v);
  if(neg)temp[len++]='-';if(c=='p'){temp[len++]='0';temp[len++]='x';}
  if(precision>64)precision=64;while((int)k<precision)rev[k++]='0';while(k)temp[len++]=rev[--k];
 }else if(c=='f'){
  double v=va_arg(ap,double);if(v<0){temp[len++]='-';v=-v;}if(!(v<1e18)){s="nonfinite";len=9;}else{
   if(precision<0)precision=6;if(precision>9)precision=9;uint64_t scale=1;for(int i=0;i<precision;i++)scale*=10;
   uint64_t whole=(uint64_t)v,frac=(uint64_t)((v-(double)whole)*(double)scale+0.5);if(frac>=scale){whole++;frac=0;}
   char rev[24];unsigned k=0;do{rev[k++]='0'+whole%10;whole/=10;}while(whole);while(k)temp[len++]=rev[--k];if(precision){temp[len++]='.';uint64_t d=scale/10;while(d){temp[len++]='0'+frac/d;frac%=d;d/=10;}}
  }
 }else{errno=22;if(cap)b[n<cap?n:cap-1]=0;return -1;}
 if(width>4096)width=4096;int pad=width>(int)len?width-(int)len:0;
 if(zero&&!left&&precision<0&&len&&s[0]=='-'){emit(b,cap,&n,'-');s++;len--;}
 if(!left)while(pad--)emit(b,cap,&n,zero&&precision<0?'0':' ');for(size_t i=0;i<len;i++)emit(b,cap,&n,s[i]);if(left)while(pad--)emit(b,cap,&n,' ');
 }if(cap)b[n<cap?n:cap-1]=0;return (int)n;}
int snprintf(char*b,size_t n,const char*f,...){va_list ap;va_start(ap,f);int r=vsnprintf(b,n,f,ap);va_end(ap);return r;}
struct MiniFile {const unsigned char*data;size_t size,pos;unsigned used,error;};
static struct MiniFile console_out,console_err,files[4];FILE *stdout=&console_out,*stderr=&console_err,*stdin;
static const unsigned char*wad;static size_t wad_length;
int phase5_mount_wad(const void*p,size_t n){if(!p||n<12||n>0x470000||memcmp(p,"IWAD",4))return 0;uint32_t count,off;memcpy(&count,(const char*)p+4,4);memcpy(&off,(const char*)p+8,4);if(off>n||count>(n-off)/16)return 0;for(uint32_t i=0;i<count;i++){uint32_t pos,size;memcpy(&pos,(const unsigned char*)p+off+i*16,4);memcpy(&size,(const unsigned char*)p+off+i*16+4,4);if(pos>n||size>n-pos)return 0;}wad=p;wad_length=n;return 1;}
FILE*fopen(const char*name,const char*mode){if(mode[0]!='r'||strchr(mode,'+')){errno=13;return NULL;}const char*base=strrchr(name,'/');base=base?base+1:name;if(!wad||strcasecmp(base,"doom1.wad")){errno=2;return NULL;}for(unsigned i=0;i<4;i++)if(!files[i].used){files[i]=(struct MiniFile){wad,wad_length,0,1,0};return &files[i];}errno=24;return NULL;}
int fclose(FILE*f){if(!f||f==stdout||f==stderr)return EOF;f->used=0;return 0;}
size_t fread(void*p,size_t sz,size_t count,FILE*f){if(!f||!f->used||!sz||count>SIZE_MAX/sz)return 0;size_t avail=(f->size-f->pos)/sz;if(count>avail)count=avail;memcpy(p,f->data+f->pos,count*sz);f->pos+=count*sz;return count;}
int fseek(FILE*f,long off,int whence){if(!f||!f->used)return -1;int64_t base=whence==0?0:whence==1?(int64_t)f->pos:whence==2?(int64_t)f->size:-1;int64_t dest=base+off;if(base<0||dest<0||(uint64_t)dest>f->size)return -1;f->pos=(size_t)dest;return 0;}
long ftell(FILE*f){return f&&f->used?(long)f->pos:-1;}
size_t fwrite(const void*p,size_t sz,size_t n,FILE*f){if(f!=stdout&&f!=stderr){errno=13;return 0;}if(sz&&n>SIZE_MAX/sz)return 0;const unsigned char*b=p;for(size_t i=0;i<sz*n;i++)putchar(b[i]);return n;}
int fflush(FILE*f){(void)f;return 0;}
int vfprintf(FILE*f,const char*fmt,va_list ap){char buf[512];int n=vsnprintf(buf,sizeof(buf),fmt,ap);if(n<0)return n;size_t used=(size_t)n<sizeof(buf)?(size_t)n:sizeof(buf)-1;if(fwrite(buf,1,used,f)!=used)return -1;return n;}
int fprintf(FILE*f,const char*fmt,...){va_list ap;va_start(ap,fmt);int r=vfprintf(f,fmt,ap);va_end(ap);return r;}
int printf(const char*fmt,...){va_list ap;va_start(ap,fmt);int r=vfprintf(stdout,fmt,ap);va_end(ap);return r;}
// Engine uses sscanf only for one integer preceded by optional literal prefix.
int sscanf(const char*s,const char*fmt,...){while(*fmt&&*fmt!='%'){if(isspace(*fmt)){while(isspace(*s))s++;fmt++;}else if(*fmt++!=*s++)return 0;}if(*fmt++!='%')return 0;int base=*fmt=='x'||*fmt=='X'?16:*fmt=='o'?8:*fmt=='i'?0:10;char*end;long v=strtol(s,&end,base);if(end==s)return 0;va_list ap;va_start(ap,fmt);int*out=va_arg(ap,int*);va_end(ap);*out=(int)v;return 1;}
int mkdir(const char*p,unsigned mode){(void)p;(void)mode;errno=13;return -1;}
int remove(const char*p){(void)p;errno=13;return -1;}int rename(const char*a,const char*b){(void)a;(void)b;errno=13;return -1;}
int system(const char*c){(void)c;errno=38;return -1;}
#ifndef PHASE5_TEST
void exit(int status){*(volatile uint32_t*)0x10004018u=0xe5000000u|(unsigned)status;for(;;){}}
void abort(void){exit(255);}
#endif
