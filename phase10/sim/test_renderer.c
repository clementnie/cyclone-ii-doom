// SPDX-License-Identifier: GPL-2.0-or-later
// Compare the actual optimized drawers against the preserved Phase 9 drawers.
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>
int centery=84;
unsigned char *colormaps;
int dg_row_skip=1;
unsigned char dg_row_next[202],dg_row_prev[202];
#define DECL(P) \
extern int P##dc_x,P##dc_yl,P##dc_yh,P##dc_iscale,P##dc_texturemid; \
extern int P##ds_y,P##ds_x1,P##ds_x2,P##ds_xfrac,P##ds_yfrac,P##ds_xstep,P##ds_ystep; \
extern unsigned char *P##dc_source,*P##dc_colormap,*P##dc_translation,*P##ds_source,*P##ds_colormap; \
extern unsigned char *P##ylookup[]; extern int P##columnofs[],P##viewwindowy,P##viewheight; \
extern void P##R_DrawColumnLow(void),P##R_DrawSpanLow(void),P##R_DrawTranslatedColumnLow(void),P##R_DrawFuzzColumnLow(void);
DECL() DECL(ref_)
extern int FixedDiv(int,int);
static unsigned char actual[64000],expected[64000],texture[4096],map[256],translation[256],cmap[8192];
static unsigned seed=0x31415926;
static unsigned rng(void){seed^=seed<<13;seed^=seed>>17;seed^=seed<<5;return seed;}
static void rows(int n){
 unsigned char selected[200]={0};
 for(int i=0;i<n;i++)selected[(i*200+200/(2*n))/n]=1;
 dg_row_next[200]=dg_row_next[201]=200;
 int prev=200;
 for(int y=0;y<200;y++){if(selected[y])prev=y;dg_row_prev[y]=prev;}
 for(int y=199;y>=0;y--)dg_row_next[y]=selected[y]?y:dg_row_next[y+1];
}
static void check(int x,int lo,int hi,int span){
 for(int y=0;y<200;y++)for(int col=0;col<320;col++){
  int drawn=dg_row_next[y]==y && (span?(y==lo&&col>=2*x&&col<=2*hi&&!(col&1)):(col==2*x&&y>=lo&&y<=hi));
  unsigned char want=drawn?expected[y*320+col]:0xa5;
  if(actual[y*320+col]!=want){fprintf(stderr,"renderer mismatch %d,%d got %u expected %u\n",col,y,actual[y*320+col],want);fprintf(stderr," x=%d lo=%d hi=%d span=%d offset=%d height=%d next=%d\n",x,lo,hi,span,viewwindowy,viewheight,dg_row_next[y]);exit(1);}
 }
}
int main(void){
 for(int i=0;i<4096;i++)texture[i]=rng();
 for(int i=0;i<256;i++){map[i]=rng();translation[i]=rng();}
 for(int i=0;i<8192;i++)cmap[i]=rng();colormaps=cmap;
 dc_source=ref_dc_source=texture;dc_colormap=ref_dc_colormap=map;dc_translation=ref_dc_translation=translation;
 ds_source=ref_ds_source=texture;ds_colormap=ref_ds_colormap=map;
 viewwindowy=ref_viewwindowy=0;viewheight=ref_viewheight=168;
 for(int y=0;y<200;y++){ylookup[y]=actual+y*320;ref_ylookup[y]=expected+y*320;}
 for(int x=0;x<320;x++)columnofs[x]=ref_columnofs[x]=x;
 for(int n=0;n<3;n++){
  rows(n==0?100:n==1?120:200);
  for(int t=0;t<120;t++){
   int off=(t%3)*8;
   viewwindowy=ref_viewwindowy=off;viewheight=ref_viewheight=168-off;
   for(int yy=0;yy<viewheight;yy++){ylookup[yy]=actual+(yy+off)*320;ref_ylookup[yy]=expected+(yy+off)*320;}
   int x=rng()%160,lo=rng()%viewheight,hi=lo+rng()%(viewheight-lo);
   dc_x=ref_dc_x=x;dc_yl=ref_dc_yl=lo;dc_yh=ref_dc_yh=hi;
   dc_texturemid=ref_dc_texturemid=64<<16;dc_iscale=ref_dc_iscale=rng()%32768;
   memset(actual,0xa5,sizeof actual);memset(expected,0xa5,sizeof expected);
   R_DrawColumnLow();ref_R_DrawColumnLow();check(x,lo+off,hi+off,0);
   memset(actual,0xa5,sizeof actual);memset(expected,0xa5,sizeof expected);
   R_DrawTranslatedColumnLow();ref_R_DrawTranslatedColumnLow();check(x,lo+off,hi+off,0);
   int end=x+rng()%(160-x),y=dg_row_next[off+rng()%(viewheight-2)]-off;
   ds_y=ref_ds_y=y;ds_x1=ref_ds_x1=x;ds_x2=ref_ds_x2=end;
   ds_xfrac=ref_ds_xfrac=rng();ds_yfrac=ref_ds_yfrac=rng();ds_xstep=ref_ds_xstep=rng();ds_ystep=ref_ds_ystep=rng();
   memset(actual,0xa5,sizeof actual);memset(expected,0xa5,sizeof expected);
   R_DrawSpanLow();ref_R_DrawSpanLow();check(x,y+off,end,1);
  }
 }
 // Fuzz must sample a neighboring displayed row and leave every skipped pixel untouched.
 extern int fuzzoffset[],fuzzpos;
 rows(100);viewwindowy=8;viewheight=160;dc_x=14;dc_yl=0;dc_yh=159;fuzzpos=0;
 for(int yy=0;yy<160;yy++)ylookup[yy]=actual+(yy+8)*320;
 for(int i=0;i<64000;i++)actual[i]=expected[i]=(i*17+(i/320)*13)&255;
 int fp=0;
 for(int y=1;y<=158;y++){
  int sy=y+8;
  if(dg_row_next[sy]==sy){
   int ny=fuzzoffset[fp]>0?dg_row_next[sy+1]:dg_row_prev[sy-1];
   if(ny<8||ny>=168)ny=sy;
   expected[sy*320+28]=cmap[6*256+expected[ny*320+28]];
  }
  if(++fp==50)fp=0;
 }
 R_DrawFuzzColumnLow();
 if(memcmp(actual,expected,sizeof actual)||fuzzpos!=fp){puts("fuzz mismatch");return 1;}
 // Model saturation with unsigned magnitudes, including INT_MIN and zero.
 for(int t=0;t<1000000;t++){
  int32_t a=t<16?(int32_t[]){0,1,-1,INT_MIN,INT_MAX,65536,-65536,16384}[t%8]:(int32_t)rng();
  if(t>=16&&t<300000)a=(int16_t)a;
  int32_t b=t<16?(t<8?0:INT_MIN):(int32_t)rng();
  if(t>=16&&t<300000)b=(int16_t)b;
  uint32_t aa=a<0?-(uint32_t)a:(uint32_t)a,bb=b<0?-(uint32_t)b:(uint32_t)b;
  int32_t want=(aa>>14)>=bb?((a^b)<0?INT_MIN:INT_MAX):(int32_t)(((int64_t)a*65536)/b);
  if(FixedDiv(a,b)!=want){fprintf(stderr,"FixedDiv mismatch %d/%d\n",a,b);return 1;}
 }
 puts("PASS renderer: 1080 actual/oracle column, translated sprite and span comparisons at 100/120/200 rows, shifted view windows and nearest-row fuzz; FixedDiv 1000000 edge/random pairs");
 return 0;
}
void I_Error(const char *fmt,...){fprintf(stderr,"Unexpected renderer range error: %s\n",fmt);exit(1);}
