// SPDX-License-Identifier: GPL-2.0-or-later
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "doomtype.h"
#include "v_patch.h"
unsigned char *I_VideoBuffer;extern unsigned char *tinttable,*ref_tinttable;
int dg_row_skip=1;
unsigned char dg_row_next[202],dg_row_prev[202];
void V_UseBuffer(unsigned char*),ref_V_UseBuffer(unsigned char*);
void V_DrawPatch(int,int,patch_t*),ref_V_DrawPatch(int,int,patch_t*);
void V_DrawPatchFlipped(int,int,patch_t*),ref_V_DrawPatchFlipped(int,int,patch_t*);
void V_DrawTLPatch(int,int,patch_t*),ref_V_DrawTLPatch(int,int,patch_t*);
void I_Error(const char *fmt,...){fprintf(stderr,"range error %s\n",fmt);exit(1);}
static unsigned char a[64000],b[64000],tint[65536],secondary[64000];
static union {uint32_t align;unsigned char bytes[4096];} p;
int main(void){
 I_VideoBuffer=a;tinttable=ref_tinttable=tint;
 for(int i=0;i<65536;i++)tint[i]=(i^(i>>8))&255;
 patch_t *patch=(patch_t*)p.bytes;patch->width=17;patch->height=39;patch->topoffset=3;patch->leftoffset=2;
 int pos=8+17*4;
 for(int x=0;x<17;x++){
  patch->columnofs[x]=pos;
  for(int part=0;part<2;part++){
   p.bytes[pos++]=part?27:1;p.bytes[pos++]=part?9:21;p.bytes[pos++]=0;
   for(int y=0;y<(part?9:21);y++)p.bytes[pos++]=x*13+y;
   p.bytes[pos++]=0;
  }
  p.bytes[pos++]=255;
 }
 void (*fn[])(int,int,patch_t*)={V_DrawPatch,V_DrawPatchFlipped,V_DrawTLPatch};
 void (*ref[])(int,int,patch_t*)={ref_V_DrawPatch,ref_V_DrawPatchFlipped,ref_V_DrawTLPatch};
 for(int n=0;n<3;n++){
  unsigned char sel[200]={0};int rows=n==0?100:n==1?120:200;
  for(int i=0;i<rows;i++)sel[(i*200+200/(2*rows))/rows]=1;
  dg_row_next[200]=dg_row_next[201]=200;
  for(int y=199;y>=0;y--)dg_row_next[y]=sel[y]?y:dg_row_next[y+1];
  for(int f=0;f<3;f++)for(int x=10;x<=11;x++)for(int y=4;y<=164;y+=40){
   memset(a,0xa5,sizeof a);memset(b,0xa5,sizeof b);V_UseBuffer(a);ref_V_UseBuffer(b);
   fn[f](x,y,patch);ref[f](x,y,patch);
   for(int yy=0;yy<200;yy++)for(int xx=0;xx<320;xx++){
    unsigned char want=sel[yy]&&!(xx&1)?b[yy*320+xx]:0xa5;
    if(a[yy*320+xx]!=want){fprintf(stderr,"patch mismatch n=%d f=%d at %d,%d\n",n,f,xx,yy);return 1;}
   }
   // Auxiliary buffers must remain complete for HUD backing and later block copies.
   memset(secondary,0xa5,sizeof secondary);V_UseBuffer(secondary);fn[f](x,y,patch);
   if(memcmp(secondary,b,sizeof b)){puts("auxiliary buffer mismatch");return 1;}
  }
 }
 puts("PASS UI patches: 90 patch/flipped/translucent cases against original, odd origins, HUD/menu positions; auxiliary buffers complete");
}
