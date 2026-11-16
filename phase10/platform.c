// SPDX-License-Identifier: GPL-2.0-or-later
// Row tables and word packing adapted from ChromatiX, Copyright (c) 2026
// Florent Kermarrec / Enjoy-Digital. BSD-2-Clause notice: licenses/ChromatiX-BSD-2-Clause.txt.
#include <stdint.h>
#define R(a) (*(volatile uint32_t *)(a))
#include "doomgeneric.h"
#include "doomkeys.h"
#include "i_video.h"
#include <string.h>
#include "r_main.h"
extern int viewwindowy,viewheight,detailLevel;
#ifndef PHASE10_ROWS
#define PHASE10_ROWS 100
#endif
#ifndef PHASE10_FULL
#define PHASE10_FULL 0
#endif
#if PHASE10_ROWS != 100 && PHASE10_ROWS != 120 && PHASE10_ROWS != 200
#error Unsupported row count
#endif
int dg_row_skip = !PHASE10_FULL;
unsigned char dg_row_next[202], dg_row_prev[202];
static unsigned short display_src[PHASE10_ROWS];
void DG_FillSkippedRows(void) {
 if(!dg_row_skip)return;
 int last=-1;
 for(int y=0;y<200;y++){
  int src=dg_row_next[y];
  if(src==y){last=y;continue;}
  if(src>=200)src=last;
  if(src>=0)memcpy(I_VideoBuffer+y*320,I_VideoBuffer+src*320,320);
 }
}
static void display_init(void) {
 for(unsigned i=0;i<PHASE10_ROWS;i++)display_src[i]=(i*200+200/(2*PHASE10_ROWS))/PHASE10_ROWS;
 unsigned prev=200,i=0;
 for(unsigned y=0;y<200;y++){if(i<PHASE10_ROWS && display_src[i]==y){prev=y;i++;}dg_row_prev[y]=prev;}
 dg_row_next[200]=dg_row_next[201]=200;
 dg_row_prev[200]=dg_row_prev[201]=prev;
 for(int y=199,i=PHASE10_ROWS-1;y>=0;y--){dg_row_next[y]=dg_row_next[y+1];if(i>=0&&display_src[i]==y){dg_row_next[y]=y;i--;}}
 detailLevel=PHASE10_FULL?0:1;
 R(0x10006024u)=PHASE10_FULL?0:(PHASE10_ROWS==100?1:PHASE10_ROWS==120?2:3);
}

static uint32_t last_cycles,elapsed_ms,remainder;
static uint32_t displayed;
void DG_Init(void) {
 last_cycles=R(0x10004004u);elapsed_ms=0;remainder=0;displayed=0;
 R(0x10006000u)=0;display_init();
}
uint32_t DG_GetTicksMs(void) {
 uint32_t now=R(0x10004004u),delta=now-last_cycles;last_cycles=now;
 // Poll at least once per 85.9s cycle-counter wrap; avoid overflow of remainder.
 elapsed_ms+=delta/50000u;remainder+=delta%50000u;
 if(remainder>=50000u){remainder-=50000u;++elapsed_ms;}
 return elapsed_ms;
}
void DG_SleepMs(uint32_t ms) {uint32_t start=DG_GetTicksMs();while(DG_GetTicksMs()-start<ms){}}
// The upstream indexed renderer exposes gamma-corrected palette entries.

void DG_DrawFrame(void) {
 uint32_t slot=displayed^1u;
 volatile uint32_t *dst=(volatile uint32_t *)(slot?0x20010000u:0x20000000u);
 // Pack only the displayed columns/rows from the actual engine buffer.
 if(PHASE10_FULL) {
  const uint32_t *src=(const uint32_t *)I_VideoBuffer;
  for(unsigned i=0;i<16000;i++)dst[i]=src[i];
 } else {
  for(unsigned y=0;y<PHASE10_ROWS;y++) {
   const uint32_t *src=(const uint32_t *)(I_VideoBuffer+display_src[y]*320);
   for(unsigned x=0;x<40;x++) {
    uint32_t a=src[2*x],b=src[2*x+1];
    dst[y*40+x]=(a&255u)|((a>>8)&0xff00u)|((b<<16)&0xff0000u)|((b<<8)&0xff000000u);
   }
  }
 }
 // Palette updates occur in vblank. Palette RAM has no atomic shadow bank.
 uint32_t frame=R(0x1000601cu);while(R(0x1000601cu)==frame){DG_GetTicksMs();}
 // Frame counter wraps at raster start, not vblank: wait for a safe video
 // interval via an explicit scanline status register (added by platform integration).
 while((R(0x10006020u)&1023u)<480u || (R(0x10006020u)&1023u)>=490u){DG_GetTicksMs();}
 for(unsigned i=0;i<256;i++)R(0x10006400u+4*i)=((colors[i].r>>4)<<8)|((colors[i].g>>4)<<4)|(colors[i].b>>4);
 R(0x10006004u)=slot;R(0x10006000u)=1;
 while(((R(0x10006008u)>>1)&1u)!=slot){DG_GetTicksMs();}
 displayed=slot;R(0x10004000u)++;
}
int DG_GetKey(int *pressed,unsigned char *key) {
 static const uint8_t keys[7]={KEY_UPARROW,KEY_DOWNARROW,KEY_LEFTARROW,KEY_RIGHTARROW,KEY_FIRE,KEY_USE,KEY_ESCAPE};
 if(!(R(0x10002004u)&0x100u))return 0;
 uint32_t event=R(0x10002000u),id=event&255u;
 if(!(event&0x80000000u)||id>=7)return 0;
 *pressed=(event>>8)&1u;*key=keys[id];return 1;
}
void DG_SetWindowTitle(const char *title){(void)title;}

// Counts real 3D renders, excluding intermediate wipe presentation frames.
void DG_GameRendered(void){R(0x1000400cu)++;}
