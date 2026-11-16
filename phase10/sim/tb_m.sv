`timescale 1ns/1ps
module tb_m;
 reg clk=0;always #10 clk=~clk;
 reg rst=1;wire valid,fetch,halted,retired;wire [31:0] addr,wdata,debug_pc,fault_pc,fault_value;
 wire [3:0] wstrb,cause;wire [1:0] size;
 wire ready=valid;wire error=0;reg [31:0] rdata;
 reg [31:0] av,bv,expected;integer fn,n,cycles;reg [31:0] vectors[0:4095];
 rv32i_cpu dut(.*);
 function [31:0] upper(input [31:0] v);upper=(v+32'h800)&32'hfffff000;endfunction
 always @* case(addr)
  0:rdata=upper(av)|32'hb7;
  4:rdata={av[11:0],5'd1,3'd0,5'd1,7'h13};
  8:rdata=upper(bv)|32'h137;
  12:rdata={bv[11:0],5'd2,3'd0,5'd2,7'h13};
  16:rdata={7'd1,5'd2,5'd1,3'(fn),5'd3,7'h33};
  20:rdata=32'h00100073;
  default:rdata=32'hffffffff;
 endcase
 initial begin
  $readmemh("phase10/build/m_vectors.hex",vectors);
  for(n=0;n<1024;n=n+1)begin
   @(negedge clk);rst=1;av=vectors[4*n];bv=vectors[4*n+1];fn=vectors[4*n+2];expected=vectors[4*n+3];
   repeat(3)@(negedge clk);rst=0;cycles=0;
   while(!halted && cycles<200)begin @(negedge clk);cycles=cycles+1;end
   if(!halted || cause!=3 || fault_pc!=20 || dut.regs[3]!==expected)
    $fatal(1,"M fn=%d a=%h b=%h got=%h expected=%h cause=%d pc=%h",fn,av,bv,dut.regs[3],expected,cause,fault_pc);
  end
  $display("PASS RV32M: 1024 directed/random MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU, zero divisors and signed overflow");$finish;
 end
endmodule
