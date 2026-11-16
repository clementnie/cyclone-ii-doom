`timescale 1ns/1ps
// Loader DATA stores followed by END's word/byte readback; no game execution.
module tb_upload_block #(parameter OBSERVED_EARLY=0, OPEN_PAGE=1);
 reg clk=0;always #10 clk=~clk;
 reg rst=1,valid=0,fetch=0;reg [31:0] addr=0,wdata=0;reg [3:0] wstrb=0;reg [1:0] size=2;
 wire ready,error,init,cke,cs,ras,cas,we;wire [31:0] rdata,refs;
 wire [11:0] a;wire [1:0] ba,dqm;wire [15:0] dq;
 phase10_sdram_controller #(.OPEN_PAGE(OPEN_PAGE)) dut(,,,clk,rst,valid,fetch,addr,wdata,wstrb,size,ready,error,rdata,init,refs,a,ba,cke,cs,ras,cas,we,dqm,dq);
 wire sdram_clk;assign #8 sdram_clk=clk;
 sdram_model #(.OBSERVED_EARLY(OBSERVED_EARLY)) model(sdram_clk,rst,cke,cs,ras,cas,we,a,ba,dqm,dq);
 task access(input [31:0] ad,wd,input [3:0] st);
 integer cycles;
 begin
  @(negedge clk);addr=ad;wdata=wd;wstrb=st;valid=1;cycles=0;
  do begin @(posedge clk);#1;cycles=cycles+1;if(cycles>10200)$fatal(1,"timeout");end while(!ready);
  if(error)$fatal(1,"bus error");
  @(negedge clk);valid=0;repeat(3)@(negedge clk);
 end endtask
 function [7:0] pattern(input integer i);pattern=(i*73+19+(i>>3))&255;endfunction
 function [31:0] word_at(input integer i);word_at={pattern(i+3),pattern(i+2),pattern(i+1),pattern(i)};endfunction
 reg [31:0] checksum;integer i,j,k;reg [31:0] bases[0:3];
 initial begin
  bases[0]='h20020000;bases[1]='h2008b100;bases[2]='h20380000;bases[3]='h207ffe00;
  repeat(5)@(negedge clk);rst=0;
  for(k=0;k<4;k=k+1)begin
   for(i=0;i<512;i=i+4)access(bases[k]+i,word_at(i),15);
   checksum=32'hffffffff;
   for(i=0;i<512;i=i+4)begin
    access(bases[k]+i,0,0);
    if(rdata!==word_at(i))$fatal(1,"block read %h got=%h expected=%h",bases[k]+i,rdata,word_at(i));
    for(j=0;j<32;j=j+1)checksum=(checksum>>1)^(32'hedb88320 & -(checksum[0]^rdata[j]));
   end
   if(~checksum!==32'hb8ce8d07)$fatal(1,"CRC mismatch %h",~checksum);
  end
  $display("PASS loader block readback: four regions, 512-byte CRC b8ce8d07; observed_early=%0d open_page=%0d",OBSERVED_EARLY,OPEN_PAGE);$finish;
 end
 initial begin #20000000;$fatal(1,"watchdog");end
endmodule
