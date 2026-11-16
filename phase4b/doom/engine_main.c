// SPDX-License-Identifier: GPL-2.0-or-later
#include "doomgeneric.h"
int main(void) {
 static char *argv[]={"doom","-iwad","doom1.wad","-mb","2","-nosound","-nomusic"};
 doomgeneric_Create(7,argv);
 for(;;)doomgeneric_Tick();
}
