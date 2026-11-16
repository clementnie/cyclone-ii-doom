#include <stdint.h>
#include <stddef.h>
#include <assert.h>
#include <stdio.h>
void *p9_copy(void*,const void*,size_t);
void *p9_fill(void*,int,size_t);
int main(void){
 unsigned char a[192],b[192],src[192];
 for(unsigned i=0;i<192;i++)src[i]=(unsigned char)(i*67+3);
 for(unsigned x=0;x<8;x++)for(unsigned y=0;y<8;y++)for(unsigned n=0;n<130;n++){
  for(unsigned k=0;k<192;k++)a[k]=b[k]=0x5a;
  p9_copy(a+x,src+y,n);
  for(unsigned k=0;k<n;k++)b[x+k]=src[y+k];
  for(unsigned k=0;k<192;k++)assert(a[k]==b[k]);
  p9_fill(a+x,0x1ab,n);
  for(unsigned k=0;k<n;k++)b[x+k]=0xab;
  for(unsigned k=0;k<192;k++)assert(a[k]==b[k]);
 }
 puts("PASS optimized memcpy/memset: all source/destination alignments, 0..129 byte lengths and surrounding guards");
}
