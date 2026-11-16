#ifndef TEST_WORDS
#define TEST_WORDS 0x200000u
#endif
typedef unsigned int u32;
#define R(a) (*(volatile u32 *)(a))
#define HEART R(0x10004000u)
#define RESULT R(0x10004008u)
#define ADDRESS R(0x10004010u)
#define ERRORS R(0x10004014u)
#define CODE R(0x10004018u)
static u32 errors,heartbeat;
static volatile u32 * const mem=(volatile u32 *)0x20000000u;
static void progress(u32 i) { ADDRESS=0x20000000u+(i<<2);HEART=++heartbeat;ERRORS=errors; }
static void check(u32 i,u32 value) {
 if(mem[i]!=value) { if(errors!=~0u) ++errors;CODE=0xe400;RESULT=2; }
}
int main(void) {
 RESULT=0;ERRORS=0;CODE=0;
 // Walking ones/zeros on each bank; address-bit isolation across all 8 MiB.
 for(u32 bank=0;bank<4;bank++) for(u32 bit=0;bit<32;bit++) {
  u32 i=bank<<19,v=1u<<bit;mem[i]=v;check(i,v);mem[i]=~v;check(i,~v);progress(i);
 }
 for(u32 pass=0;pass<2;pass++) {
  for(u32 bit=0;bit<21;bit++) mem[1u<<bit]=pass?~(1u<<bit):1u<<bit;
  for(u32 bit=0;bit<21;bit++) check(1u<<bit,pass?~(1u<<bit):1u<<bit);
 }
 // Separate full sweeps catch aliasing; zero/ones/address/inverse address.
 for(u32 pass=0;pass<4;pass++) {
  for(u32 i=0;i<TEST_WORDS;i++) {
   u32 v=pass==0?0:pass==1?~0u:pass==2?(0xa5a50000u^(i<<2)):~(0xa5a50000u^(i<<2));
   mem[i]=v;if((i&1023u)==0)progress(i);
  }
  for(u32 i=0;i<TEST_WORDS;i++) {
   u32 v=pass==0?0:pass==1?~0u:pass==2?(0xa5a50000u^(i<<2)):~(0xa5a50000u^(i<<2));
   check(i,v);if((i&1023u)==0)progress(i);
  }
 }
 // Byte/halfword stores at beginning/end of each bank, independently read as words.
 for(u32 bank=0;bank<4;bank++) for(u32 end=0;end<2;end++) {
  u32 i=(bank<<19)+(end?0x7ffffu:0);mem[i]=0;
  volatile unsigned char *b=(volatile unsigned char *)&mem[i];
  b[0]=0x12;b[1]=0x34;b[2]=0x56;b[3]=0x78;check(i,0x78563412u);
  volatile unsigned short *h=(volatile unsigned short *)&mem[i];
  h[0]=0xcdef;h[1]=0x89ab;check(i,0x89abcdefu);
 }
#ifdef SIMULATION_TEST_EXECUTE
 // Exercise actual instruction fetch/return from external RAM, no I-cache.
 mem[0]=0x00700513u; // addi a0,zero,7
 mem[1]=0x00008067u; // jalr zero,ra,0
 if(((u32 (*)(void))0x20000000u)()!=7u) {++errors;CODE=0xe401;}
#endif
 ERRORS=errors;RESULT=errors?2:1;ADDRESS=0x207ffffcu;
 u32 tick=R(0x10004004u);
 for(;;) {u32 now=R(0x10004004u);if(now-tick>=500000u){HEART=++heartbeat;tick=now;}}
}
