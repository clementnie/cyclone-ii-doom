`timescale 1ns/1ps
module tb_soc;
 reg clk=0;always #10 clk=~clk;
 reg rst=1,mem_rst=1;
 wire [11:0] a;wire [1:0] ba,dqm;wire [15:0] dq;
 wire cke,cs,ras,cas,we,halted;wire [3:0] cause;wire [31:0] pc,hb;
 phase4_soc #(.ROM_FILE("build/sim.hex")) dut(.clk(clk),.rst(rst),.memory_rst(mem_rst),.ps2_clk(1'b1),.ps2_data(1'b1),
 .pixel_clk(),.hs(),.vs(),.blank(),.red(),.green(),.blue(),.halted(halted),.cause(cause),.debug_pc(pc),.mailbox(hb),.frames(),
 .dram_addr(a),.dram_ba(ba),.dram_dqm(dqm),.dram_cke(cke),.dram_cs_n(cs),.dram_ras_n(ras),.dram_cas_n(cas),.dram_we_n(we),.dram_dq(dq));
 wire sdram_clk;assign #8 sdram_clk=clk;
 sdram_model model(sdram_clk,mem_rst,cke,cs,ras,cas,we,a,ba,dqm,dq);
 integer cycles=0,retired=0;
 initial begin
  repeat(5)@(negedge clk);mem_rst=0;rst=0;
  wait(dut.external_memory.state==6);
  repeat(3)@(negedge clk);rst=1;
  repeat(1000)@(negedge clk);
  if(dut.external_memory.refresh_count==0)$fatal(1,"warm reset stopped refresh");
  rst=0;
 end
 always @(posedge clk) if(!rst) begin
  cycles=cycles+1;if(dut.retired)retired=retired+1;
  if(halted)$fatal(1,"CPU trap %d pc %h",cause,pc);
  if(dut.fabric.ram_result==2)$fatal(1,"CPU SDRAM diagnostic failed");
  if(dut.fabric.ram_result==1)begin
   if(dut.fabric.key_events!=0 || hb<5)$fatal(1,"diagnostic status");
   $display("PASS CPU SDRAM diagnostic (32-word full-sweep simulation, all bank/alias/walking tests), cycles=%0d retired=%0d",cycles,retired);$finish;
  end
  if(cycles>2000000)$fatal(1,"CPU timeout pc %h",pc);
 end
endmodule
