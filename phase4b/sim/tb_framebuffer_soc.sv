`timescale 1ns/1ps
module tb_framebuffer_soc #(parameter PLATFORM=0);
 reg clk=0;always #10 clk=~clk;
 reg rst=1,mem_rst=1;
 wire [11:0] a;wire [1:0] ba,dqm;wire [15:0] dq;
 wire cke,cs,ras,cas,we,halted,hs,vs,blank;
 wire [3:0] cause;wire [31:0] pc,hb,frames;wire [9:0] red,green,blue;
 phase4b_soc #(.ROM_FILE(PLATFORM?"build/platform.hex":"build/sim.hex")) dut(.clk(clk),.rst(rst),.memory_rst(mem_rst),.ps2_clk(1'b1),.ps2_data(1'b1),
 .pixel_clk(),.hs(hs),.vs(vs),.blank(blank),.red(red),.green(green),.blue(blue),.halted(halted),.cause(cause),.debug_pc(pc),.mailbox(hb),.frames(frames),
 .dram_addr(a),.dram_ba(ba),.dram_dqm(dqm),.dram_cke(cke),.dram_cs_n(cs),.dram_ras_n(ras),.dram_cas_n(cas),.dram_we_n(we),.dram_dq(dq));
 wire sdram_clk;assign #8 sdram_clk=clk;
 sdram_model model(sdram_clk,mem_rst,cke,cs,ras,cas,we,a,ba,dqm,dq);
 initial begin repeat(5)@(negedge clk);mem_rst=0;rst=0;end
 function [7:0] pixel(input integer x,y);
 integer p,row,bitno,digit,bits,xx,yy;
 begin
  if(y<64)p=x<64?1:x<128?2:x<192?3:x<256?4:0;
  else if(y<128)p=((x>>4)^(y>>4))&1?4:0;else p=3;
  if(x==y || x==319-y)p=5;
  if(x>=144 && x<168 && y>=144 && y<160)p=6;
  if(y>=166 && y<198 && x>=8 && x<80)begin
   row=(y-166)/11;yy=(y-166)%11;digit=(x-8)/8;xx=(x-8)%8;
   if(yy<10)begin
    if(digit==0)bits=row==0?16'h7b24:row==1?16'h5bed:16'h5b6f;
    else bits=(row==1 && digit==8)?16'h2c97:16'h7b6f;
    p=(xx<6 && ((bits>>(14-(yy/2)*3-(xx/2)))&1))?(row==2?1:4):0;
   end
  end
  pixel=p;
 end endfunction
 function [11:0] color(input [7:0] p);
 case(p&7)0:color=0;1:color=12'hf00;2:color=12'h0f0;3:color=12'h00f;4:color=12'hfff;5:color=12'hff0;6:color=12'h0ff;7:color=12'hf0f;endcase
 endfunction
 integer pidx;
 integer x,y,count=0,frame_count=0,cycles=0;reg sample;reg started=0;reg [11:0] expected;reg [31:0] cpu_start,refs_start;
 always @(posedge clk)begin
  sample=dut.fabric.pixels.ce2;
  #1;
  if(!rst)begin
   cycles=cycles+1;
   if(halted)$fatal(1,"CPU trap cause %d pc %h",cause,pc);
   if(cycles>25000000)$fatal(1,"timeout pc %h hb %h",pc,hb);
   if(dut.fabric.fb_active && sample)begin
    x=dut.fabric.pixels.scan_x;y=dut.fabric.pixels.scan_y;
    if(!started && x==0 && y==0)begin started=1;cpu_start=dut.cpu_words;refs_start=dut.external_memory.refresh_count;end
    if(started)begin
     if(hs!==!(x>=656 && x<752) || vs!==!(y>=490 && y<492))$fatal(1,"sync alignment %d,%d",x,y);
     if(PLATFORM)begin
      pidx=((x/2)^((y-40)/2))&255;
      expected=(x<640 && y>=40 && y<440)?{4'((pidx>>4)&15),4'(((255-pidx)>>4)&15),4'(((pidx^128)>>4)&15)}:0;
     end else expected=(x<640 && y>=40 && y<440)?color(pixel(x/2,(y-40)/2)):0;
     if({red[9:6],green[9:6],blue[9:6]}!==expected)$fatal(1,"pixel %d,%d got %h expected %h row0tag %d row1tag %d uf %d",x,y,{red[9:6],green[9:6],blue[9:6]},expected,dut.fabric.pixels.tag0,dut.fabric.pixels.tag1,dut.fabric.underflows);
     count=count+1;
     if(x==799 && y==524)begin
      frame_count=frame_count+1;
      if(count!=420000*frame_count)$fatal(1,"frame pixel count %d",count);
      if(frame_count==(PLATFORM?1:3))begin
       if(dut.fabric.underflows!=0)$fatal(1,"underflows %d",dut.fabric.underflows);
       if(!PLATFORM && dut.cpu_words-cpu_start<100)$fatal(1,"CPU starvation");
       if(dut.external_memory.refresh_count-refs_start<100)$fatal(1,"refresh starvation");
       $display("PASS CPU -> SDRAM -> palette -> VGA: %0d complete frames, %0d pixels; underflows=0; CPU grants=%0d VGA=%0d max wait=%0d cycles",frame_count,count,dut.cpu_words-cpu_start,dut.video_words,dut.max_video_wait);$finish;
      end
     end
    end
   end
  end
 end
endmodule
