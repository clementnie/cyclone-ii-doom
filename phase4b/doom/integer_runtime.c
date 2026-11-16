// SPDX-License-Identifier: GPL-2.0-or-later
#include <stdint.h>
uint32_t __udivsi3(uint32_t n,uint32_t d) {
 if(!d)return ~0u;
 uint32_t q=0,r=0;
 for(int i=31;i>=0;i--) {
  uint32_t carry=r>>31;r=(r<<1)|((n>>i)&1u);
  if(carry || r>=d){r-=d;q|=1u<<i;}
 }
 return q;
}
uint32_t __mulsi3(uint32_t a,uint32_t b){uint32_t r=0;while(b){if(b&1u)r+=a;a<<=1;b>>=1;}return r;}
uint32_t __umodsi3(uint32_t n,uint32_t d){return n-__mulsi3(__udivsi3(n,d),d);}
int32_t __divsi3(int32_t a,int32_t b){uint32_t x=a<0?0u-(uint32_t)a:(uint32_t)a,y=b<0?0u-(uint32_t)b:(uint32_t)b;uint32_t q=__udivsi3(x,y);return (a<0)!=(b<0)?(int32_t)(0u-q):(int32_t)q;}
int32_t __modsi3(int32_t a,int32_t b){return (int32_t)((uint32_t)a-__mulsi3((uint32_t)__divsi3(a,b),(uint32_t)b));}
