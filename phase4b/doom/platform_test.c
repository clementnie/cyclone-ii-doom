// SPDX-License-Identifier: GPL-2.0-or-later
#include "doomgeneric.h"
#include "i_video.h"
static pixel_t pixels[320*200];
pixel_t *DG_ScreenBuffer=pixels;
struct color colors[256];
int main(void) {
 DG_Init();
 for(unsigned i=0;i<256;i++){colors[i].r=i;colors[i].g=255-i;colors[i].b=i^128u;}
 for(unsigned y=0;y<200;y++)for(unsigned x=0;x<320;x++)pixels[y*320+x]=(x^y)&255;
 DG_DrawFrame();
 for(;;){int pressed;unsigned char key;DG_GetKey(&pressed,&key);DG_SleepMs(1);}
}
