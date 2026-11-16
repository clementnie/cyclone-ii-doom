`timescale 1ns/1ps
module tb_top;
 reg CLOCK_50=0; always #10 CLOCK_50=~CLOCK_50;
 reg [0:0] KEY=1;
 reg PS2_CLK=1,PS2_DAT=1;
 wire VGA_CLK,VGA_HS,VGA_VS,VGA_BLANK,VGA_SYNC;
 wire [9:0] VGA_R,VGA_G,VGA_B;
 wire [0:0] LEDR;
 de2_phase2 dut(.*);
 integer i;
 time first_rise;
 initial begin
  // Includes configuration-initialized reset counter and project-relative ROM.
  wait(!dut.reset_pipe[1]);
  if($time<1310700) $fatal(1,"power-on reset released too soon");
  wait(dut.soc.mailbox==1);
  if(LEDR[0] || VGA_SYNC!==0) $fatal(1,"board diagnostic outputs");
  @(posedge VGA_CLK); first_rise=$time;
  @(posedge VGA_CLK); if($time-first_rise!=40) $fatal(1,"board DAC period");
  #3; KEY=0;
  #1; if(dut.reset_pipe!==2'b11) $fatal(1,"asynchronous reset assertion");
  repeat(3) @(negedge CLOCK_50);
  if(dut.soc.debug_pc!=0 || dut.soc.mailbox!=0) $fatal(1,"reset must restart CPU and peripherals");
  KEY=1;
  @(posedge CLOCK_50); #1; if(!dut.reset_pipe[1]) $fatal(1,"reset released without synchronization");
  @(posedge CLOCK_50); #1; if(dut.reset_pipe[1]) $fatal(1,"reset did not release");
  wait(dut.soc.mailbox==1);
  $display("PASS board top: power-on hold, synchronized button reset/reboot, ROM path and DAC clock"); $finish;
 end
 initial begin #20000000; $fatal(1,"board shell timeout"); end
endmodule
