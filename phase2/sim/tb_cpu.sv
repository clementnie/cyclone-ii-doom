`timescale 1ns/1ps
`include "cpu_meta.vh"
module tb_cpu;
 reg clk=0; always #10 clk=~clk;
 reg rst=1;
 wire valid,fetch,halted,retired;
 wire [31:0] addr,wdata,debug_pc,fault_pc,fault_value;
 wire [3:0] wstrb,cause; wire [1:0] size;
 reg ready=0,error=0; reg [31:0] rdata=0;
 rv32i_cpu dut(.*);
 reg [7:0] mem[0:65535];
 reg [31:0] program_words[0:`PROGRAM_WORDS-1];
 reg [31:0] expected[0:`TRACE_STEPS*33-1];
 reg pending=0,served=0;
 reg [31:0] lfsr=32'h12345678;
 integer delay_count=0,n,lane,step=0;
 reg waiting=0; reg [69:0] request;
 always @(posedge clk) begin
  if(rst) begin ready<=0; pending<=0; served<=0; waiting<=0; end
  else begin
   // Test request stability across arbitrary wait states.
   if(waiting && {addr,wdata,wstrb,size} !== request) $fatal(1,"request changed while stalled");
   waiting<=valid && !ready;
   request<={addr,wdata,wstrb,size};
   ready<=0;
   lfsr<={lfsr[30:0],lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
   if(!valid) served<=0;
   if(valid && !pending && !served) begin pending<=1; delay_count<=lfsr[2:0]; end
   if(pending) begin
    if(delay_count!=0) delay_count<=delay_count-1;
    else begin
     pending<=0; served<=1; ready<=1;
     for(lane=0;lane<4;lane=lane+1) begin
      rdata[lane*8+:8]<=mem[{addr[15:2],2'b0}+lane];
      if(wstrb[lane]) mem[{addr[15:2],2'b0}+lane]<=wdata[lane*8+:8];
     end
    end
   end
  end
 end
 always @(posedge clk) begin
  #1;
  if(!rst && retired) begin
   if(step>=`TRACE_STEPS) $fatal(1,"extra retirement");
   if(debug_pc !== expected[step*33]) $fatal(1,"PC mismatch at step %0d: got %h expected %h",step,debug_pc,expected[step*33]);
   for(n=0;n<32;n=n+1)
    if(dut.regs[n] !== expected[step*33+1+n]) $fatal(1,"x%0d mismatch at step %0d: got %h expected %h",n,step,dut.regs[n],expected[step*33+1+n]);
   step=step+1;
  end
  if(halted) begin
   if(cause!=3 || fault_pc!=`STOP_PC || step!=`TRACE_STEPS) $fatal(1,"unexpected trap/trace length");
   $display("PASS CPU: %0d retirement states, all 32 registers and PC, random bus stalls",step); $finish;
  end
 end
 integer i,j;
 initial begin
  for(i=0;i<65536;i=i+1) mem[i]=0;
  $readmemh("build/cpu_program.hex",program_words);
  $readmemh("build/cpu_trace.hex",expected);
  for(i=0;i<`PROGRAM_WORDS;i=i+1)
   for(j=0;j<4;j=j+1) mem[i*4+j]=program_words[i][j*8+:8];
  repeat(4) @(negedge clk); rst=0;
 end
 initial begin #2000000; $fatal(1,"CPU timeout"); end
endmodule
