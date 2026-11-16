`timescale 1ns/1ps
module de2_phase2(
 input wire CLOCK_50, input wire [0:0] KEY,
 input wire PS2_CLK,PS2_DAT,
 output wire VGA_CLK,VGA_HS,VGA_VS,VGA_BLANK,VGA_SYNC,
 output wire [9:0] VGA_R,VGA_G,VGA_B,
 output wire [0:0] LEDR
);
 reg [15:0] power_on=0;
 reg [1:0] reset_pipe=2'b11;
 always @(posedge CLOCK_50)
  if(!(&power_on)) power_on<=power_on+1'b1;
 always @(posedge CLOCK_50 or negedge KEY[0]) begin
  if(!KEY[0]) reset_pipe<=2'b11;
  else if(!(&power_on)) reset_pipe<=2'b11;
  else reset_pipe<={reset_pipe[0],1'b0};
 end
 assign VGA_SYNC=1'b0;
 // Path relative to the Phase 2 Quartus project working directory.
 phase2_soc #(.ROM_FILE("../firmware/boot.hex")) soc(
  .clk(CLOCK_50),.rst(reset_pipe[1]),.ps2_clk(PS2_CLK),.ps2_data(PS2_DAT),
  .pixel_clk(VGA_CLK),.hs(VGA_HS),.vs(VGA_VS),.blank(VGA_BLANK),
  .red(VGA_R),.green(VGA_G),.blue(VGA_B),.halted(LEDR[0]),
  .cause(),.debug_pc(),.mailbox(),.frames());
endmodule
