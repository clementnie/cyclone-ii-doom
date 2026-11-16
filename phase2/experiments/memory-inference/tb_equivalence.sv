`timescale 1ns/1ps
module tb_equivalence;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,valid=0,fetch=0;
 reg [31:0] addr=0,wdata=0;
 reg [3:0] wstrb=0;
 wire ar,ae,br,be; wire [31:0] ad,bd;
 onchip_memory_original a(clk,rst,valid,fetch,addr,wdata,wstrb,ar,ae,ad);
 onchip_memory b(clk,rst,valid,fetch,addr,wdata,wstrb,br,be,bd);
 integer cycles=0,i; integer seed=32'h1382;
 task tick;
 begin
  @(posedge clk); #1;
  if ({ar,ae,ad} !== {br,be,bd})
   $fatal(1,"mismatch cycle %0d addr %h orig %h new %h",cycles,addr,{ar,ae,ad},{br,be,bd});
  cycles=cycles+1;
  @(negedge clk);
 end
 endtask
 initial begin
  tick; rst=0;
  // Initialize every word through the interface, then exercise every mask.
  for(i=0;i<2048;i=i+1) begin
   valid=0; tick;
   addr=32'h10000+4*i; valid=1; wstrb=15; wdata=$random(seed); tick;
  end
  for(i=0;i<16;i=i+1) begin
   valid=0; tick;
   addr=32'h10000; valid=1; wstrb=i; wdata=$random(seed); tick;
   wdata=~wdata; tick; // held valid must not write twice
   rst=1; tick; rst=0; tick; // reset preserves contents and suppresses writes
  end
  for(i=0;i<20000;i=i+1) begin
   wdata=$random(seed); wstrb=$random(seed);
   valid=($random(seed)&3)!=0; rst=($random(seed)&31)==0; fetch=$random(seed);
   case(i%8)
    0: addr=$random(seed)&32'h1fff;
    1,2,3,4: addr=32'h10000+($random(seed)&32'h1fff);
    5: addr=32'h12000;
    6: addr=32'h2000;
    7: addr=$random(seed);
   endcase
   tick;
  end
  $display("PASS memory equivalence: %0d cycles, all words/masks, held valid, reset, fetch, invalid addresses",cycles);
  $finish;
 end
endmodule
