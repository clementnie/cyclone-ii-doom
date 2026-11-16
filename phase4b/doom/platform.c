// SPDX-License-Identifier: GPL-2.0-or-later
#include <stdint.h>
#include "doomgeneric.h"
#include "doomkeys.h"
#include "i_video.h"
#define R(a) (*(volatile uint32_t *)(a))
static uint32_t last_cycles,elapsed_ms,remainder;
static uint32_t displayed;
void DG_Init(void) {
 last_cycles=R(0x10004004u);elapsed_ms=0;remainder=0;displayed=0;
 R(0x10006000u)=0;
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
 const uint8_t *src=(const uint8_t *)DG_ScreenBuffer;
 for(unsigned i=0;i<16000;i++) {
  *dst++=(uint32_t)src[0]|((uint32_t)src[1]<<8)|((uint32_t)src[2]<<16)|((uint32_t)src[3]<<24);src+=4;
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
