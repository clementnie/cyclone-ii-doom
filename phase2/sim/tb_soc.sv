`timescale 1ns/1ps
module tb_soc;
 reg clk=0; always #10 clk=~clk;
 reg rst=1,ps2_clk=1,ps2_data=1;
 wire pixel_clk,hs,vs,blank,halted;
 wire [9:0] red,green,blue;
 wire [3:0] cause;
 wire [31:0] debug_pc,mailbox,frames;
 phase2_soc dut(.*);
 task send_bit(input bit b);
  begin ps2_clk=1;ps2_data=b; #40003;ps2_clk=0;#39997;ps2_clk=1; end
 endtask
 task scan(input [7:0] b);
  integer k;
  begin
   send_bit(0); for(k=0;k<8;k=k+1) send_bit(b[k]);
   send_bit(~^b);send_bit(1);ps2_data=1;#80000;
  end
 endtask
 always @(posedge clk) if(!rst && halted) $fatal(1,"SoC halted cause %0d pc %h",cause,debug_pc);
 always @(negedge pixel_clk) begin
  #1;
  if(!rst && blank && ^{red,green,blue}===1'bx) $fatal(1,"unknown pixel");
 end
 reg [31:0] saved,old_frames;
 initial begin
  repeat(5) @(negedge clk); rst=0;
  if(dut.fabric.ram_result!==0) $fatal(1,"false PASS at reset");
  wait(mailbox==1);
  if(dut.fabric.ram_result!==0) $fatal(1,"PASS before test ran");
  wait(dut.fabric.ram_result==1);
  if(dut.fabric.diag_error!=0) $fatal(1,"RAM self test error");
  wait(mailbox>=3);
  scan(8'h29); wait(dut.fabric.key_events==1);
  if(dut.fabric.last_key!==32'h105) $fatal(1,"space make");
  $display("SoC: key make observed at %t",$time);
  scan(8'hf0); scan(8'h29); wait(dut.fabric.key_events==2);
  if(dut.fabric.last_key!==32'h005) $fatal(1,"space break");
  $display("SoC: key break observed at %t",$time);
  force dut.fabric.keyboard.overflow_sticky=1;
  wait(dut.fabric.diag_error==32'he003);
  $display("SoC: overflow observed at %t",$time);
  release dut.fabric.keyboard.overflow_sticky;
  // A parity failure must become visible and remain sticky.
  send_bit(0);
  for(integer k=0;k<8;k=k+1) send_bit((8'h29>>k)&1);
  send_bit(^8'h29);send_bit(1);ps2_data=1;
  wait(dut.fabric.diag_error==32'he004);
  $display("SoC: parity observed at %t",$time);
  // Pause CPU in its idle bus-gap state: VGA continues, CPU value freezes.
  wait(dut.cpu.state==3);
  @(negedge clk); force dut.cpu.state=3;
  saved=mailbox; old_frames=frames;
  wait(frames>=old_frames+2);
  if(mailbox!==saved) $fatal(1,"heartbeat advanced without CPU");
  if(dut.fabric.video.dashboard.fc==0) $fatal(1,"frame snapshot not running");
  release dut.cpu.state;
  wait(mailbox!=saved);
  $display("PASS SoC: real firmware RAM test, CPU-only heartbeat/stall/resume, PS/2 make/break/parity, independent VGA refresh");
  $finish;
 end
 initial begin #150000000; $fatal(1,"SoC timeout pc=%h hb=%h ram=%h",debug_pc,mailbox,dut.fabric.ram_result); end
endmodule
