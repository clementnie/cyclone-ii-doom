// Actual Phase 4 CPU RTL; bounded functional bus model, not SDRAM timing evidence.
#include "Vcpu_top.h"
#include "verilated.h"
#include <vector>
#include <fstream>
#include <iostream>
#include <cstring>
#include <cstdint>
#include <stdexcept>
#include <chrono>
std::vector<uint8_t> ram(8<<20,0xa5), local(8192,0xa5),rom(8192,0);
uint32_t le(const uint8_t*p){return p[0]|p[1]<<8|p[2]<<16|p[3]<<24;}
void put(uint8_t*p,uint32_t v){for(int i=0;i<4;i++)p[i]=v>>(8*i);}
std::vector<uint8_t> file(const char*p){std::ifstream f(p,std::ios::binary);if(!f)throw std::runtime_error(p);return {std::istreambuf_iterator<char>(f),{}};}
uint32_t crc(const uint8_t*p,size_t n){uint32_t c=~0u;while(n--){c^=*p++;for(int j=0;j<8;j++)c=(c>>1)^(0xedb88320u&-(c&1));}return ~c;}
uint8_t* mem(uint32_t a){if(a<8192)return rom.data()+a;if(a>=0x10000&&a<0x12000)return local.data()+a-0x10000;if(a>=0x20000000&&a<0x20800000)return ram.data()+a-0x20000000;return nullptr;}
struct Sym{uint32_t a;std::string name;};
int main(int argc,char**argv){try{
 if(argc<4)throw std::runtime_error("boot ELF IWAD symbols [max_cycles] [frames]");
 auto elf=file(argv[1]),wad=file(argv[2]);if(wad.size()>0x470000)throw std::runtime_error("WAD overflow");
 uint32_t ph=le(&elf[28]),entry=le(&elf[24]);unsigned num=elf[44]|elf[45]<<8,sz=elf[42]|elf[43]<<8;
 for(unsigned i=0;i<num;i++){auto*p=&elf.at(ph+i*sz);if(le(p)!=1)continue;uint32_t off=le(p+4),a=le(p+8),n=le(p+16),m=le(p+20);if(a<0x20020000||a>0x20380000||m>0x20380000-a||n>m||off+n>elf.size())throw std::runtime_error("ELF bounds");std::memcpy(mem(a),elf.data()+off,n);}
 std::memcpy(mem(0x20380000),wad.data(),wad.size());put(mem(0x10100),0x57414435);put(mem(0x10104),0x20380000);put(mem(0x10108),wad.size());put(mem(0x1010c),crc(wad.data(),wad.size()));
 // ROM trampoline: LUI t0,entry[31:12]; JALR zero,t0,entry[11:0].
 if(entry&0xfff)throw std::runtime_error("unaligned trampoline");put(rom.data(),(entry&0xfffff000)|0x2b7);put(rom.data()+4,0x28067);
 std::vector<Sym> symbols;std::ifstream sy(argv[3]);std::string a,t,n;uint32_t log=0,lp=0,hh=0,heap=0;while(sy>>a>>t>>n){uint32_t v=std::stoul(a,nullptr,16);symbols.push_back({v,n});if(n=="phase5_log")log=v;if(n=="phase5_log_position")lp=v;if(n=="phase6_heap_high")hh=v;if(n=="__heap_start")heap=v;}
 std::vector<std::vector<uint8_t>> packets;
 bool loading=argc>6;
 if(loading){auto boot=file(argv[6]);if(boot.size()>rom.size())throw std::runtime_error("ROM overflow");std::fill(rom.begin(),rom.end(),0);std::copy(boot.begin(),boot.end(),rom.begin());std::fill(ram.begin(),ram.end(),0xa5);std::fill(local.begin(),local.end(),0xa5);
 std::ifstream f(argv[7]);std::string line;while(f>>line){if(line.size()!=120)throw std::runtime_error("packet size");std::vector<uint8_t> b(60);for(int i=0;i<60;i++)b[i]=std::stoul(line.substr(118-2*i,2),nullptr,16);packets.push_back(b);}}
 size_t pi=0;uint32_t ack=0,result=0,status=0;bool sent=false;std::vector<uint8_t> source(60,0);
 Vcpu_top c;c.rst=1;c.ready=0;c.error=0;c.rdata=0;for(int i=0;i<3;i++){c.clk=0;c.eval();c.clk=1;c.eval();}c.rst=0;
 uint64_t max=argc>4?std::stoull(argv[4]):10000000000ull,retired=0;unsigned goal=argc>5?std::stoul(argv[5]):1;
 uint32_t regs[8]={},pal[256]={},slot=0,active=0,seenlog=0,minsp=0x20800000,frame=0;bool served=false;uint64_t cycles;auto start=std::chrono::steady_clock::now();bool pass=false,log_ready=false;
 for(cycles=0;cycles<max;cycles++){
  if(loading&&pi<packets.size()){
   if(sent&&ack==le(source.data())){if(argc>8&&pi+1==packets.size()&&std::stoul(argv[8],nullptr,16)!=0xe6000008u){
    uint32_t expected=std::stoul(argv[8],nullptr,16);if(status!=expected)throw std::runtime_error("unexpected loader status "+std::to_string(status));
    for(unsigned i=0;i<0x20000;i++)if(ram[i]!=0xa5)throw std::runtime_error("framebuffer overwritten");
    for(unsigned i=0x7f0000;i<0x800000;i++)if(ram[i]!=0xa5)throw std::runtime_error("stack overwritten");
    std::cout<<"PASS loader status "<<std::hex<<status<<"; framebuffer/stack guards intact\n";return 0;}
   if((status&0xff000000)==0xe6000000)throw std::runtime_error("loader rejection "+std::to_string(status));pi++;sent=false;}
   if(!sent&&pi<packets.size()&&(status||pi)){source=packets[pi];sent=true;}
  }
  if(argc>8&&std::stoul(argv[8],nullptr,16)==0xe6000008u&&status==0xe6000008u){
   if(le(mem(0x10100)))throw std::runtime_error("timeout kept valid descriptor");
   std::cout<<"PASS ROM inactivity timeout invalidates session/descriptor; simulated counter x256\n";return 0;}
  c.clk=0;c.eval();c.ready=0;c.error=0;
  // Registered bounded memory response; hold served until request deasserts.
  if(!c.valid)served=false;
  if(c.valid&&!served){served=true;c.ready=1;uint32_t ad=c.addr&~3u;auto*p=mem(ad);uint32_t v=0;bool ok=true;
   if(p){if(c.wstrb&&ad<8192)ok=false;else {v=le(p);for(int i=0;i<4;i++)if(c.wstrb>>i&1)p[i]=c.wdata>>(8*i);}}
   else if(ad>=0x10007000&&ad<0x1000703c)v=le(source.data()+ad-0x10007000);
   else if(ad==0x10007040){v=result;if(c.wstrb)result=c.wdata;}
   else if(ad==0x10007044){v=ack;if(c.wstrb)ack=c.wdata;}
   else if(ad==0x10007048){v=status;if(c.wstrb)status=c.wdata;}
   else if(ad>=0x10004000&&ad<0x10004020){unsigned r=(ad-0x10004000)/4;v=r==1?uint32_t(cycles*(argc>8&&std::stoul(argv[8],nullptr,16)==0xe6000008u?256:1)):regs[r];if(c.wstrb)regs[r]=c.wdata;}
   else if(ad==0x10006000){v=active;if(c.wstrb)active=c.wdata&1;}
   else if(ad==0x10006004){v=slot;if(c.wstrb)slot=c.wdata&1;}
   else if(ad==0x10006008)v=active|(slot<<1);
   else if(ad==0x1000601c||ad==0x10003008)v=cycles/840000;
   else if(ad==0x10006020)v=(cycles%840000)/1600;
   else if(ad>=0x10006400&&ad<0x10006800){if(c.wstrb)pal[(ad-0x10006400)/4]=c.wdata;}
   else if(ad==0x10002000||ad==0x10002004)v=0;
   else if(ad==0x10003000||ad==0x10003004||(ad>=0x10010000&&ad<0x100112c0)){}
   else ok=false;
   c.rdata=v;c.error=!ok;if(!ok)std::cerr<<"BUS FAULT pc="<<std::hex<<c.pc<<" address="<<ad<<std::dec<<"\n";
  }
  c.eval();c.clk=1;c.eval();retired+=c.retired;
  if(c.sp>=0x207f0000&&c.sp<minsp)minsp=c.sp;
  if((cycles&65535)==0&&lp){uint32_t end=le(mem(lp));if(end==0)log_ready=true;if(!log_ready)end=0;if(end-seenlog>4096)seenlog=end-4096;while(seenlog<end){std::cout<<char(*mem(log+(seenlog&4095)));seenlog++;}std::cout.flush();}
  if((cycles%100000000)==0){std::cerr<<"cycles="<<cycles<<" pc="<<std::hex<<c.pc<<std::dec<<" retired="<<retired<<"\n";}
  if(regs[6]){std::cerr<<"EXIT diagnostic="<<std::hex<<regs[6]<<std::dec<<"\n";break;}
  if(c.halted){std::cerr<<"TRAP cause="<<unsigned(c.cause)<<" pc="<<std::hex<<c.fault_pc<<" value="<<c.fault_value<<std::dec<<"\n";break;}
  if(regs[0]>frame){frame=regs[0];auto*p=mem(slot?0x20010000:0x20000000);uint32_t sum=crc(p,64000);std::cerr<<"FRAME "<<frame<<" CRC32="<<std::hex<<sum<<std::dec<<" cycles="<<cycles<<"\n";
   std::ofstream im("phase6/artifacts/frame.ppm",std::ios::binary);im<<"P6\n320 200\n255\n";for(int i=0;i<64000;i++){uint32_t rgb=pal[p[i]];for(int sh=8;sh>=0;sh-=4)im.put(((rgb>>sh)&15)*17);}if(frame>=goal){pass=true;break;}}
 }
 double secs=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
 uint32_t high=hh?le(mem(hh)):0;
 std::ofstream report("phase6/reports/cpu-boot.json");report<<"{\"pass\":"<<(pass?"true":"false")<<",\"cycles\":"<<cycles<<",\"retired\":"<<retired<<",\"frames\":"<<frame<<",\"pc\":"<<c.pc<<",\"stack_bytes\":"<<(0x20800000-minsp)<<",\"heap_high_address\":"<<high<<",\"heap_span\":"<<(high>heap?high-heap:0)<<",\"wall_seconds\":"<<secs<<",\"bus_model\":\"functional, no SDRAM timing\"}\n";
 std::cerr<<"RESULT pass="<<pass<<" cycles="<<cycles<<" stack="<<0x20800000-minsp<<" heap_span="<<(high>heap?high-heap:0)<<" wall="<<secs<<"s\n";
 return pass?0:1;
 }catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 2;}}
