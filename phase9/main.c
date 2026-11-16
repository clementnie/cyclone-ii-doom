// SPDX-License-Identifier: GPL-2.0-or-later
#include <stdint.h>
#include "firmware/crc32.h"
#include <stdlib.h>
#include "doomgeneric.h"
extern int phase5_mount_wad(const void *,unsigned int);
// Future ROM loader leaves {magic,base,length,CRC32} here after loading assets.
// A compiled ELF alone does not provide this loader or descriptor.
static int mount_boot_wad(void) {
 volatile const uint32_t *d=(volatile const uint32_t*)0x00010100u;
 uint32_t magic=d[0],base=d[1],length=d[2],expected=d[3];
 if(magic!=0x57414435u || base!=0x20380000u || length<12 || length>0x470000u)return 0;
 const unsigned char *bytes=(const unsigned char*)base;
 if(crc32(bytes,length)!=expected)return 0;
 return phase5_mount_wad(bytes,length);
}
int main(void) {
 static char *argv[]={"doom","-iwad","doom1.wad","-mb","2","-nosound","-nomusic","-warp","1","1","-skill","3"};
 if(!mount_boot_wad())exit(1);
 doomgeneric_Create(12,argv);
 for(;;)doomgeneric_Tick();
}
