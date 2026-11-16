`timescale 1ns/1ps
module tb_sdram #(parameter OPEN_PAGE=1);
 reg clk=0; always #10 clk=~clk;
 reg rst=1,valid=0,fetch=0;reg [31:0] addr=0,wdata=0;reg [3:0] wstrb=0;reg [1:0] size=2;
 wire ready,error,init,cke,cs,ras,cas,we;wire [31:0] rdata,refs;
 wire [11:0] a;wire [1:0] ba,dqm;wire [15:0] dq;
 phase9_sdram_controller #(.OPEN_PAGE(OPEN_PAGE),.POWER_CYCLES(10000)) dut(,,,clk,rst,valid,fetch,addr,wdata,wstrb,size,ready,error,rdata,init,refs,a,ba,cke,cs,ras,cas,we,dqm,dq);
 wire sdram_clk;assign #8 sdram_clk=clk;
 sdram_model model(sdram_clk,rst,cke,cs,ras,cas,we,a,ba,dqm,dq);
 reg [31:0] expected[0:2047];integer i,j,n,seed=42;reg [31:0] value,location,mask;integer total_latency=0,accesses=0,seq_latency=0,seq_count=0;integer max_latency=0,latency,normal_max=0;
 task access(input [31:0] ad,wd,input [3:0] st,input [1:0] sz,input fail,input [31:0] exp);
 begin
  @(negedge clk);addr=ad;wdata=wd;wstrb=st;size=sz;valid=1;latency=0;
  do begin @(posedge clk);#1;latency=latency+1;if(latency>10100) $fatal(1,"timeout");end while(!ready);
  total_latency=total_latency+latency;accesses=accesses+1;
  if(latency>max_latency) max_latency=latency;
  if(latency<1000 && latency>normal_max)normal_max=latency;
  if(error!==fail) $fatal(1,"error mismatch %h",ad);
  if(st==0 && !fail && rdata!==exp) $fatal(1,"read %h got %h expected %h",ad,rdata,exp);
  repeat(3) begin @(posedge clk);#1;if(ready) $fatal(1,"duplicate completion");end
  @(negedge clk);valid=0;@(posedge clk);#1;
 end endtask
 function [31:0] address(input integer index);
  address=32'h20000000+((index&3)<<21)+((index>>2)<<2);
 endfunction
 initial begin
  repeat(5) @(negedge clk);rst=0;
  // First request waits through real 200us initialization.
  access(32'h20000000,32'h12345678,15,2,0,0);
  if($time<200000) $fatal(1,"short initialization");
  for(i=0;i<2048;i=i+1) begin expected[i]=$random(seed);access(address(i),expected[i],15,2,0,0);end
  for(i=0;i<2048;i=i+1)begin access(address(i),0,0,2,0,expected[i]);seq_latency=seq_latency+latency;seq_count=seq_count+1;end
  for(i=0;i<3000;i=i+1) begin
   j=($random(seed)&32'h7fffffff)%2048;n=($random(seed)&3);value=$random(seed);
   mask=32'hff<<(n*8);expected[j]=(expected[j]&~mask)|(value&mask);
   access(address(j)+n,value,1<<n,0,0,0);
   access(address(j),0,0,2,0,expected[j]);
   n=($random(seed)&1)*2;value=$random(seed);mask=32'hffff<<(n*8);
   expected[j]=(expected[j]&~mask)|(value&mask);
   access(address(j)+n,value,3<<n,1,0,0);
   access(address(j)+n,0,0,1,0,expected[j]);
  end
  access(32'h207ffffc,32'hdeadbeef,15,2,0,0);access(32'h207ffffc,0,0,2,0,32'hdeadbeef);
  access(32'h20800000,0,0,2,1,0);access(32'h1ffffffc,0,0,2,1,0);
  access(32'h20000001,0,0,2,1,0);access(32'h20000000,0,2,0,1,0);
  fetch=1;access(32'h207ffffc,0,0,2,0,32'hdeadbeef);access(32'h20000000,0,15,2,1,0);fetch=0;
  repeat(2000) @(negedge clk);
  access(32'h207ffffc,0,0,2,0,32'hdeadbeef);
  wait(dut.refresh_timer==700);
  access(32'h207ffffc,0,0,2,0,32'hdeadbeef);
  if(latency>45)$fatal(1,"refresh request latency bound");
  if(refs<10) $fatal(1,"no refresh under traffic");
  @(negedge clk);valid=1;addr=32'h20000000;repeat(5) @(negedge clk);rst=1;
  repeat(5) @(negedge clk);valid=0;rst=0;
  access(32'h20000000,32'habcdef01,15,2,0,0);access(32'h20000000,0,0,2,0,32'habcdef01);
  $display("BENCH OPEN_PAGE=%d mixed_cycles=%d accesses=%d sequential_cycles=%d sequential_requests=%d",OPEN_PAGE,total_latency,accesses,seq_latency,seq_count);
  $display("Normal request max latency: %0d cycles",normal_max);
  $display("PASS SDRAM randomized lanes, banks, rows, bounds, refresh, reset; max latency incl init=%0d",max_latency);$finish;
 end
 initial begin #100000000;$fatal(1,"watchdog");end
 // Refresh deadline includes a bounded in-flight transaction, never starvation.
 integer last_ref=0,ticks=0;
 always @(posedge clk) begin
  ticks=ticks+1;
  if(rst || !init || dut.state==11)last_ref=ticks;
  if(ticks-last_ref>740)$fatal(1,"refresh starvation");
 end
endmodule
