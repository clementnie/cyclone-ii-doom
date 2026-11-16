#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
extern void *p5_malloc(size_t),*p5_calloc(size_t,size_t),*p5_realloc(void*,size_t);extern void p5_free(void*);
extern int p5_snprintf(char*,size_t,const char*,...);extern int p5_sscanf(const char*,const char*,...);extern double p5_atof(const char*);
extern int p5_phase5_mount_wad(const void*,size_t);extern void *p5_fopen(const char*,const char*);extern size_t p5_fread(void*,size_t,size_t,void*);extern int p5_fseek(void*,long,int),p5_fclose(void*);extern long p5_ftell(void*);
extern char *p5_strstr(const char*,const char*);extern void *p5_memmove(void*,const void*,size_t);
int main(void){
 void*a=p5_malloc(128),*b=p5_malloc(256),*c=p5_malloc(128);assert(a&&b&&c&&!((uintptr_t)a&15));memset(b,0x5a,256);b=p5_realloc(b,512);for(int i=0;i<256;i++)assert(((unsigned char*)b)[i]==0x5a);
 p5_free(a);p5_free(b);p5_free(c);void*big=p5_malloc(900000);assert(big);p5_free(big);assert(!p5_malloc(SIZE_MAX));assert(!p5_calloc(SIZE_MAX,2));
 unsigned char*z=p5_calloc(31,7);for(int i=0;i<217;i++)assert(!z[i]);p5_free(z);
 char buf[128],ref[128];int n=p5_snprintf(buf,sizeof(buf),"%08x %.8s %2.2d %i %p",0x123,"ABCDEFGHIJK",3,-42,(void*)(uintptr_t)0x1234);int m=snprintf(ref,sizeof(ref),"%08x %.8s %2.2d %i %p",0x123,"ABCDEFGHIJK",3,-42,(void*)(uintptr_t)0x1234);assert(n==m&&!strcmp(buf,ref));
 assert(p5_snprintf(buf,4,"abcdef")==6&&!strcmp(buf,"abc"));assert(p5_snprintf(NULL,0,"hello %d",12)==8);
 p5_snprintf(buf,sizeof(buf),"%.2f %08d",1.125,-12);assert(!strcmp(buf,"1.13 -0000012"));
 int v=0;assert(p5_sscanf(" 0x2a"," 0x%x",&v)==1&&v==42);assert(p5_sscanf("037"," %i",&v)==1&&v==31);assert(p5_sscanf("x","%d",&v)==0);
 assert(fabs(p5_atof(" -1.25e2")+125)<1e-9);assert(p5_strstr("abc","")!=NULL);char move[]="abcdef";p5_memmove(move+1,move,5);assert(!memcmp(move,"aabcde",6));
 unsigned char wad[32]={ 'I','W','A','D',1,0,0,0,16,0,0,0, 'D','A','T','A',12,0,0,0,4,0,0,0,'T','E','S','T',0,0,0,0};
 assert(p5_phase5_mount_wad(wad,sizeof(wad)));void*f=p5_fopen("./doom1.wad","rb");assert(f);assert(!p5_fopen("doom1.wad","wb"));assert(!p5_fopen("config.cfg","rb"));assert(!p5_fseek(f,12,SEEK_SET));assert(p5_fread(buf,1,4,f)==4&&!memcmp(buf,"DATA",4));assert(p5_ftell(f)==16);assert(p5_fseek(f,-100,SEEK_CUR)==-1);assert(p5_fseek(f,100,SEEK_SET)==-1);assert(!p5_fseek(f,0,SEEK_END));assert(!p5_fread(buf,1,1,f));assert(!p5_fclose(f));
 wad[8]=33;assert(!p5_phase5_mount_wad(wad,sizeof(wad)));
 puts("PASS bounded allocator/realloc/coalescing/overflow; format/parse/string; synthetic WAD read/seek/EOF/write refusal");return 0;}
