`timescale 1ns/1ps
module tb_traps;
 reg clk=0; always #10 clk=~clk;
 reg rst=1;
 wire valid,fetch,halted,retired;
 wire [31:0] addr,wdata,debug_pc,fault_pc,fault_value;
 wire [3:0] wstrb,cause; wire [1:0] size;
 reg [31:0] instruction;
 reg fail_fetch=0,fail_data=0;
 wire ready=valid;
 wire error=fetch?fail_fetch:fail_data;
 wire [31:0] rdata=fetch?instruction:32'hdeadbeef;
 rv32i_cpu dut(.*);
 integer tests=0;
 task run(input [31:0] ins, input [3:0] expected_cause, input [31:0] expected_value,
          input bit f_error,input bit d_error);
  integer count;
  begin
   @(negedge clk); rst=1; instruction=ins; fail_fetch=f_error; fail_data=d_error;
   repeat(3) @(negedge clk); rst=0;
   count=0;
   while(!halted && count<20) begin @(negedge clk); count=count+1; end
   if(!halted || cause!==expected_cause || fault_pc!==0 || fault_value!==expected_value)
    $fatal(1,"trap instruction %h got cause=%d value=%h",ins,cause,fault_value);
   if(dut.regs[1]!==0 || valid) $fatal(1,"trap must suppress writeback and transactions");
   repeat(3) @(negedge clk);
   if(!halted) $fatal(1,"trap not sticky");
   tests=tests+1;
  end
 endtask
 initial begin
  run(32'h00000073,11,0,0,0); // ECALL
  run(32'h00100073,3,0,0,0); // EBREAK
  run(32'hffffffff,2,32'hffffffff,0,0);
  run(32'h040000b3,2,32'h040000b3,0,0); // reserved funct7
  run(32'h300010f3,2,32'h300010f3,0,0); // CSR
  run(32'h0000100f,2,32'h0000100f,0,0); // FENCE.I
  run(32'h00101083,4,1,0,0); // LH at 1
  run(32'h00202083,4,2,0,0); // LW at 2
  run(32'h000010a3,6,1,0,0); // SH at 1
  run(32'h00002123,6,2,0,0); // SW at 2
  run(32'h002000ef,0,2,0,0); // JAL target 2
  run(32'h002000e7,0,2,0,0); // JALR target 2
  run(32'h00000163,0,2,0,0); // BEQ taken target 2
  run(32'h00000013,1,0,1,0); // fetch access fault
  run(32'h00002003,5,0,0,1); // LW x0 still faults
  run(32'h00002023,7,0,0,1); // store access fault
  $display("PASS traps: %0d cases",tests); $finish;
 end
 initial begin #100000; $fatal(1,"trap timeout"); end
endmodule
