// SPDX-License-Identifier: GPL-2.0-or-later
// Volatile-only host loader. No Flash/SRAM controller is accessed.
#include <stdint.h>
#define R(a) (*(volatile uint32_t *)(a))
#define J 0x10007000u
#define CMD R(J)
#define ADDR R(J+4)
#define D(i) R(J+8+4*(i))
#define RESULT R(J+0x40)
#define ACK R(J+0x44)
#define STATUS R(J+0x48)
#define DIAG R(0x10004008u)
#define CYCLES R(0x10004004u)
#define DESC ((volatile uint32_t*)0x10100u)
static uint32_t lo[8],hi[8];
#include "crc32.h"

int main(void){
 uint32_t last=CMD,when=CYCLES,base=0,len=0,pos=0,count=0,expected=0,wad=0,active=0;
 DESC[0]=0;RESULT=0;ACK=last;STATUS=0xd6000001;DIAG=0xd6000001;
 for(;;){
  uint32_t cmd=CMD;if(cmd==last){
   if((uint32_t)(CYCLES-when)>250000000u){active=0;count=0;wad=0;expected=0;DESC[0]=0;STATUS=0xe6000008;DIAG=0xe6000008;when=CYCLES;}continue;
  }
  last=cmd;uint32_t op=cmd>>24,a=ADDR,v=D(0),err=0;
  switch(op){
  case 1: // RESET: expected executable segment count
   active=0;count=0;wad=0;DESC[0]=0;expected=v;
   if(!expected||expected>7){expected=0;err=1;}break;
  case 2: // BEGIN: aligned, bounded nonoverlapping range, len bytes
   if(!expected||active||!v||(a&3)||count>=8){err=2;break;}
   if(!((a>=0x20020000u&&a<0x20380000u&&v<=0x20380000u-a)||
        (a==0x20380000u&&v>=12&&v<=0x470000u))){err=3;break;}
   for(uint32_t i=0;i<count;i++)if(a<hi[i]&&lo[i]<a+v)err=4;
   if(!err){base=a;len=v;pos=0;active=1;}break;
  case 3: // DATA: up to 13 LE words, final partial bytes explicit in BEGIN
   if(!active||pos>=len){err=5;break;}
   for(uint32_t i=0;i<13&&pos<len;i++){
    uint32_t word=D(i),n=len-pos;if(n>4)n=4;
    if(n==4){R(base+pos)=word;pos+=4;}
    else for(uint32_t b=0;b<n;b++)*(volatile unsigned char*)(base+pos++)=word>>(8*b);
   }break;
  case 4: // END verifies actual SDRAM readback, never only receive checksum
   if(!active||pos!=len){err=6;break;}
   {uint32_t crc=crc32((void*)base,len);RESULT=crc;
    if(crc!=v){err=7;break;}
    lo[count]=base;hi[count]=base+len;count++;active=0;
    if(base==0x20380000u){DESC[1]=base;DESC[2]=len;DESC[3]=crc;DESC[0]=0x57414435u;wad=1;}
   }break;
  case 5: // EXEC only after complete verified manifest + WAD
   if(active||!wad||count!=expected+1||(a&3)){err=9;break;}
   {uint32_t found=0;for(uint32_t i=0;i<count;i++)if(lo[i]<0x20380000u&&a>=lo[i]&&a<hi[i])found=1;
    if(!found){err=10;break;}
    STATUS=0xd6000005;DIAG=0xd6000005;ACK=cmd;
    ((void(*)(void))a)();err=11;
   }break;
  default:err=12;
  }
  if(err){active=0;expected=0;count=0;wad=0;DESC[0]=0;STATUS=0xe6000000|err;DIAG=0xe6000000|err;}
  else {STATUS=0xd6000000|op;DIAG=0xd6000000|op;}
  when=CYCLES;ACK=cmd;
 }
}
