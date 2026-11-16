`timescale 1ns/1ps
module tb_mmio;
 reg clk=0;always #10 clk=~clk;reg rst=1,valid=0,fetch=0;reg [31:0]addr=0,wdata=0;reg[3:0]wstrb=0;reg[1:0]size=2;
 wire ready,error;wire[31:0]rdata;
 phase4b_bus dut(.clk(clk),.rst(rst),.valid(valid),.fetch(fetch),.addr(addr),.wdata(wdata),.wstrb(wstrb),.size(size),.ready(ready),.error(error),.rdata(rdata),
 .cpu_halted(1'b0),.cpu_cause(4'b0),.ext_ready(1'b0),.ext_error(1'b0),.ext_data(32'b0),.ext_valid(),
 .ps2_clk(1'b1),.ps2_data(1'b1),.dma_valid(),.dma_addr(),.dma_ready(1'b0),.dma_error(1'b0),.dma_data(32'b0),
 .video_words(32'h11112222),.cpu_words(32'h33334444),.max_video_wait(32'd54),
 .pixel_clk(),.hs(),.vs(),.blank(),.red(),.green(),.blue(),.frames(),.mailbox());
 integer checks=0;
 task access(input[31:0]a,d,input[3:0]st,input[1:0]sz,input f,e,input[31:0]expected);
 begin
  @(negedge clk);valid=1;addr=a;wdata=d;wstrb=st;size=sz;fetch=f;#1;
  if(!ready || error!==e)$fatal(1,"MMIO fault addr=%h",a);
  if(!e && st==0 && rdata!==expected)$fatal(1,"MMIO read addr=%h data=%h expected=%h",a,rdata,expected);
  @(posedge clk);#1;if(ready)$fatal(1,"held valid repeated completion");
  @(negedge clk);wdata=32'hbad;repeat(3)@(negedge clk);valid=0;@(posedge clk);checks=checks+1;
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  access('h10006000,0,0,2,0,0,0);access('h10006000,1,15,2,0,0,0);access('h10006000,0,0,2,0,0,1);
  access('h10006004,1,15,2,0,0,0);access('h10006008,0,0,2,0,0,4);
  access('h10006010,0,0,2,0,0,'h11112222);access('h10006014,0,0,2,0,0,'h33334444);access('h10006018,0,0,2,0,0,54);
  access('h1000640c,'habc,15,2,0,0,0);
  if(dut.pixels.palette[3]!==12'habc)$fatal(1,"palette write/served");
  access('h1000640c,0,0,2,0,1,0);access('h10006008,1,15,2,0,1,0);
  access('h10006000,0,1,0,0,1,0);access('h10006000,0,0,2,1,1,0);
  access('h10006024,0,0,2,0,1,0);access('h10006800,0,15,2,0,1,0);
  $display("PASS framebuffer MMIO: %0d request/held-valid, palette, status and access-fault checks",checks);$finish;
 end
endmodule
