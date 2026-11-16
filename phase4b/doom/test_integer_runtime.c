#include <stdint.h>
#include <stdio.h>
#include <limits.h>
extern uint32_t __udivsi3(uint32_t,uint32_t),__umodsi3(uint32_t,uint32_t),__mulsi3(uint32_t,uint32_t);
extern int32_t __divsi3(int32_t,int32_t),__modsi3(int32_t,int32_t);
int main(void){uint32_t s=7;for(unsigned i=0;i<100000;i++){
 s=s*1664525u+1013904223u;uint32_t a=s;s=s*1664525u+1013904223u;uint32_t b=s|1u;
 if(__udivsi3(a,b)!=a/b || __umodsi3(a,b)!=a%b || __mulsi3(a,b)!=a*b)return 1;
 int32_t x=(int32_t)a,y=(int32_t)b;
 if(!(x==INT_MIN&&y==-1)&&(__divsi3(x,y)!=x/y || __modsi3(x,y)!=x%y))return 2;
 }puts("PASS RV32I software integer runtime: 100000 signed/unsigned cases");return 0;}
