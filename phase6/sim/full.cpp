// Complete unchanged CPU/controller/arbiter/video + Phase6 mailbox, with
// host source/probe emulation and a digital BL1 CL2 SDRAM device model.
#include "Vfull_top.h"
#include "verilated.h"
#include <fstream>
#include <iostream>
#include <vector>
#include <array>
#include <chrono>
#include <stdexcept>
#include <cstdint>
uint32_t crc(const uint8_t*p,size_t n){uint32_t c=~0u;while(n--){c^=*p++;for(int j=0;j<8;j++)c=(c>>1)^(0xedb88320u&-(c&1));}return ~c;}
int main(int argc,char**argv){try{
 if(argc<2)throw std::runtime_error("full upload.hex [maxcycles] [gameframes]");
 std::ifstream f(argv[1]);std::string line;std::vector<std::array<uint32_t,15>> packets;
 while(f>>line){if(line.size()!=120)throw std::runtime_error("packet size");std::array<uint32_t,15> p;for(int i=0;i<15;i++)p[i]=std::stoul(line.substr(112-i*8,8),nullptr,16);packets.push_back(p);}
 std::vector<uint16_t> mem(4<<20,0xa5a5);Vfull_top c;c.rst=1;c.dq_oe=0;c.dq_in=0;
 for(int j=0;j<15;j++)c.source[j]=0;
 for(int i=0;i<8;i++){c.clk=0;c.eval();c.clk=1;c.eval();}c.rst=0;
 uint64_t max=argc>2?std::stoull(argv[2]):20000000000ull,cycles=0,retired=0;
 unsigned goal=argc>3?std::stoul(argv[3]):3,rows[4]={},active=0,refs=0;int pending=-1;unsigned index=0;uint16_t q=0;
 uint64_t lastact[4]={},lastpre[4]={},lastwrite[4]={},lastref=0;bool mode=false;
 size_t pi=0;bool sent=false;uint32_t minsp=0x20800000;unsigned seen=0,captured=0,scan_count=0;bool capture=false,pass=false;std::vector<uint8_t> pixels(640*480*3);
 auto start=std::chrono::steady_clock::now();
 for(;cycles<max;cycles++){
  if(pi<packets.size()){
   if(sent&&c.probe[0]==packets[pi][0]){
    if((c.probe[2]&0xff000000)==0xe6000000)throw std::runtime_error("loader error "+std::to_string(c.probe[2]));
    pi++;sent=false;
    if(pi%8192==0||pi==packets.size())std::cout<<"UPLOAD "<<pi<<"/"<<packets.size()<<" cycles="<<cycles<<std::endl;
   }
   if(!sent&&pi<packets.size()&&c.probe[2]){for(int j=0;j<15;j++)c.source[j]=packets[pi][j];sent=true;}
  }
  c.clk=0;c.eval();c.clk=1;c.eval();retired+=c.retired;
  if(c.halted){std::cerr<<"TRAP cause="<<unsigned(c.cause)<<" pc="<<std::hex<<c.fault_pc<<" value="<<c.fault_value<<std::dec<<std::endl;break;}
  if(c.diag){std::cerr<<"EXIT "<<std::hex<<c.diag<<std::dec<<std::endl;break;}
  if(c.sp>=0x207f0000&&c.sp<minsp)minsp=c.sp;
  // Forwarded SDRAM rising edge follows controller launch. CL2 data is
  // driven before the subsequent controller sampling edge. Electrical
  // setup/hold remains covered by the existing delayed RTL model/regression.
  bool was_oe=c.dq_oe;uint16_t was_q=q;c.dq_oe=0;if(pending>=0){if(!pending){q=mem[index];c.dq_oe=1;pending=-1;}else pending--;}
  if(c.cke&&!c.cs){unsigned cmd=c.ras*4+c.cas*2+c.we,b=c.ba;
   if(cmd==2){for(int i=0;i<4;i++)if((c.a&1024)||i==int(b)){if((active>>i&1)&&(cycles-lastact[i]<3||cycles-lastwrite[i]<2))throw std::runtime_error("tRAS/tWR");active&=~(1<<i);lastpre[i]=cycles;}}
   else if(cmd==1){if(active)throw std::runtime_error("refresh with active row");lastref=cycles;refs++;}
   else if(cmd==0){if(c.a!=0x20||refs<8)throw std::runtime_error("SDRAM mode");mode=true;}
   else if(cmd==3){if(!mode||(active>>b&1)||cycles-lastpre[b]<2)throw std::runtime_error("ACT");active|=1<<b;rows[b]=c.a;lastact[b]=cycles;}
   else if(cmd==4||cmd==5){if(!(active>>b&1)||cycles-lastact[b]<2)throw std::runtime_error("COLUMN");unsigned ix=(b<<20)|(rows[b]<<8)|(c.a&255);
    if(cmd==5){index=ix;pending=1;}
    else {uint16_t mask=(c.dqm&1?0:255)|(c.dqm&2?0:65280);mem[ix]=(mem[ix]&~mask)|(c.dq_out&mask);lastwrite[b]=cycles;}
   }
  }
  c.dq_in=q;if(was_oe!=bool(c.dq_oe)||was_q!=q)c.eval();
  if(cycles%100000000==0)std::cout<<"CYCLES "<<cycles<<" PC "<<std::hex<<c.pc<<std::dec<<" packets="<<pi<<" frames="<<c.hb<<" uf="<<c.underflows<<std::endl;
  if(c.hb!=seen){seen=c.hb;std::cout<<"GAMEFRAME "<<seen<<" cycles="<<cycles<<std::endl;}
  if(seen>=goal&&c.pixel){
   if(!capture&&c.x==0&&c.y==0){capture=true;scan_count=0;}
   if(capture){if(c.x<640&&c.y<480){unsigned off=(c.y*640+c.x)*3;for(int k=0;k<3;k++)pixels[off+k]=((c.rgb>>(8-k*4))&15)*17;}scan_count++;
    if(c.x==799&&c.y==524){if(scan_count!=420000)throw std::runtime_error("scan count");captured++;capture=false;if(captured==2){pass=!c.underflows;break;}}
   }
  }
 }
 std::ofstream im("phase6/artifacts/vga.ppm",std::ios::binary);im<<"P6\n640 480\n255\n";im.write((char*)pixels.data(),pixels.size());
 double sec=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
 uint32_t sum=crc((uint8_t*)mem.data(),64000);
 uint32_t highaddr=0,heapbase=0,heaphigh=0;std::ifstream sy("phase6/build/symbols.txt");std::string sa,st,sn;
 while(sy>>sa>>st>>sn){if(sn=="phase6_heap_high")highaddr=std::stoul(sa,nullptr,16);if(sn=="__heap_start")heapbase=std::stoul(sa,nullptr,16);}
 if(highaddr>=0x20000000&&highaddr<0x20800000){unsigned ix=(highaddr-0x20000000)/2;heaphigh=mem[ix]|uint32_t(mem[ix+1])<<16;}
 std::ofstream r("phase6/reports/full-boot.json");r<<"{\"pass\":"<<(pass?"true":"false")<<",\"cycles\":"<<cycles<<",\"retired\":"<<retired<<",\"frames\":"<<seen<<",\"vga_frames_captured\":"<<captured<<",\"underflows\":"<<c.underflows<<",\"stack_bytes\":"<<0x20800000-minsp<<",\"framebuffer_a_crc32\":"<<sum<<",\"heap_span\":"<<(heaphigh>heapbase?heaphigh-heapbase:0)<<",\"wall_seconds\":"<<sec<<"}\n";
 std::cout<<"RESULT "<<pass<<" cycles="<<cycles<<" wall="<<sec<<std::endl;return pass?0:1;
 }catch(std::exception&e){std::cerr<<e.what()<<std::endl;return 2;}}
