`timescale 1ns/1ps
module tb_keyboard;
 reg clk=0;always #10 clk=~clk;
 reg rst=1,pk=1,pd=1;wire [11:0] a;wire [1:0] ba,dqm;wire [15:0] dq;
 wire cke,cs,ras,cas,we,halted;wire [3:0] cause;wire [31:0] pc,hb;wire [9:0] red,green,blue;
 phase4b_soc #(.ROM_FILE("firmware/boot.hex")) dut(.clk(clk),.rst(rst),.memory_rst(rst),.ps2_clk(pk),.ps2_data(pd),
 .pixel_clk(),.hs(),.vs(),.blank(),.red(red),.green(green),.blue(blue),.halted(halted),.cause(cause),.debug_pc(pc),.mailbox(hb),.frames(),
 .dram_addr(a),.dram_ba(ba),.dram_dqm(dqm),.dram_cke(cke),.dram_cs_n(cs),.dram_ras_n(ras),.dram_cas_n(cas),.dram_we_n(we),.dram_dq(dq));
 wire sc;assign #8 sc=clk;sdram_model model(sc,rst,cke,cs,ras,cas,we,a,ba,dqm,dq);
 task bit_send(input b);begin pd=b;#40000;pk=0;#40000;pk=1;end endtask
 task send(input [7:0] b);integer i;begin bit_send(0);for(i=0;i<8;i=i+1)bit_send(b[i]);bit_send(~^b);bit_send(1);pd=1;#80000;end endtask
 integer cycles=0;reg sample;
 always @(posedge clk)begin
  sample=dut.fabric.pixels.ce2;
  if(!rst)begin cycles=cycles+1;if(cycles%10000000==0)$display("Keyboard test cycles=%0d hb=%0d pc=%h enabled=%b slot=%b keys=%b",cycles,hb,pc,dut.fabric.fb_active,dut.fabric.fb_active_slot,dut.fabric.keyboard.keys_down);if(halted)$fatal(1,"trap %d at %h",cause,pc);if(cycles>60000000)$fatal(1,"keyboard timeout hb=%h",hb);end
 end
 initial begin
  repeat(5)@(negedge clk);rst=0;
  $display("Keyboard stimulus starts");send(8'he0);send(8'h75); // real serialized extended Up make
  wait(dut.fabric.fb_active && dut.fabric.fb_active_slot);$display("Second image active: hb=%0d",hb);
  wait(dut.fabric.pixels.scan_x==288 && dut.fabric.pixels.scan_y==324);#1;
  if({red[9:6],green[9:6],blue[9:6]}!==12'h0ff)$fatal(1,"Up did not move rectangle into expected pixel");
  send(8'h76); // Escape selects preserved diagnostic fallback
  wait(!dut.fabric.fb_active);$display("Diagnostic fallback active: hb=%0d",hb);
  send(8'hf0);send(8'h76);send(8'h76); // release and make Escape
  send(8'he0);send(8'hf0);send(8'h75); // Up break
  wait(dut.fabric.fb_active);
  if(dut.fabric.underflows!=0)$fatal(1,"keyboard/flip underflow");
  $display("PASS serialized PS/2 -> CPU firmware -> moved SDRAM rectangle -> RGB; Escape fallback/restore; heartbeat=%0d",hb);$finish;
 end
endmodule
