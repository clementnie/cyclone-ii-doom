`timescale 1ns/1ps
module tb_scanout;
 reg clk=0;always #10 clk=~clk;
 reg rst=1,en=0,slot=0,pal_we=0;reg [7:0] pa=0;reg [11:0] pd=0;
 wire valid;wire [31:0] addr;reg ready=0,err=0;reg [31:0] data=0;
 wire active,active_slot,pending,pclk,hs,vs,blank;wire [31:0] uf,frames;wire [11:0] rgb;wire [9:0] x,y;
 framebuffer dut(clk,rst,en,slot,pal_we,pa,pd,valid,addr,ready,err,data,active,active_slot,pending,uf,frames,pclk,hs,vs,blank,rgb,x,y);
 integer delay_count=0,seed=33,cycle=0,grants=0;reg served=0,stall=0;
 reg [31:0] accepted_addr;
 function [11:0] palette(input [7:0] index);palette={index[7:4],index[3:0],index[7:4]^index[3:0]};endfunction
 function [7:0] value(input integer xx,yy,ss);value=(xx^yy)^(ss?128:0);endfunction
 integer i,xx,yy,off;reg [11:0] expected;reg sample;
 always @(posedge clk)begin
  cycle=cycle+1;ready<=0;
  if(rst)begin served<=0;delay_count<=0;end
  else if(!valid)served<=0;
  else if(!served)begin
   served<=1;accepted_addr<=addr;delay_count<=($random(seed)&31)+1;
  end else if(delay_count>0 && !stall)begin
   delay_count<=delay_count-1;
   if(delay_count==1)begin
    off=accepted_addr[15:0];yy=off/320;xx=off%320;
    data<={value(xx+3,yy,accepted_addr[16]),value(xx+2,yy,accepted_addr[16]),value(xx+1,yy,accepted_addr[16]),value(xx,yy,accepted_addr[16])};
    ready<=1;grants=grants+1;
   end
  end
 end
 integer checked=0,frame_seen=0,errors_before=0;reg checking=0;
 always @(posedge clk)begin
  sample=dut.ce2;#1;
  if(checking && sample)begin
   if(hs!==!(x>=656 && x<752)||vs!==!(y>=490 && y<492)||blank!==(x<640&&y<480))$fatal(1,"raster");
   expected=(x<640&&y>=40&&y<440)?palette(value(x/2,(y-40)/2,active_slot)):0;
   if(rgb!==expected)$fatal(1,"unit pixel x=%d y=%d got %h expected %h slot %d",x,y,rgb,expected,active_slot);
   checked=checked+1;
  end
 end
 task next_frame;begin wait(x==799&&y==524);@(negedge clk);wait(x==0&&y==0);@(negedge clk);end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  for(i=0;i<256;i=i+1)begin pal_we=1;pa=i;pd=palette(i);@(negedge clk);end
  pal_we=0;en=1;wait(active);next_frame();checking=1;
  next_frame();next_frame();checking=0;
  if(uf!=0)$fatal(1,"normal underflows %d",uf);
  // Request another buffer in active video: active slot must wait for vblank.
  wait(y==100);@(negedge clk);slot=1;
  wait(y==400);if(active_slot!=0)$fatal(1,"torn swap");
  wait(active_slot);next_frame();checking=1;next_frame();checking=0;
  if(uf!=0)$fatal(1,"swap underflows");
  // Miss a deadline deliberately: raster continues, counter records it.
  stall=1;repeat(200000)@(negedge clk);stall=0;
  wait(uf!=0);next_frame();next_frame();checking=1;next_frame();checking=0;
  // Force DMA error and prove error accounting, then reset and re-enable.
  errors_before=uf;wait(valid);err=1;wait(ready);@(posedge clk);#1;@(negedge clk);err=0;
  if(uf<=errors_before)$fatal(1,"DMA error not counted");
  @(negedge clk);rst=1;repeat(5)@(negedge clk);rst=0;
  wait(active);next_frame();checking=1;next_frame();checking=0;
  if(uf!=0)$fatal(1,"reset recovery");
  $display("PASS scanout: %0d reference pixels, palette, swap, forced late DMA/error, reset; grants=%0d",checked,grants);$finish;
 end
 initial begin #300000000;$fatal(1,"watchdog");end
endmodule
