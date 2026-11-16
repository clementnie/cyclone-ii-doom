`timescale 1ns/1ps
module starter_phase7_profile(
 input wire CLOCK_50,input wire [0:0] KEY,input wire PS2_CLK,PS2_DAT,
 output wire VGA_HS,VGA_VS,output wire [3:0] VGA_R,VGA_G,VGA_B,output wire [0:0] LEDR,
 output wire DRAM_CLK,DRAM_CKE,DRAM_CS_N,DRAM_RAS_N,DRAM_CAS_N,DRAM_WE_N,
 output wire [11:0] DRAM_ADDR,output wire [1:0] DRAM_BA,DRAM_DQM,inout wire [15:0] DRAM_DQ
);
 wire clk,locked;
 phase4_pll clocks(.inclk0(CLOCK_50),.c0(clk),.c1(DRAM_CLK),.locked(locked));
 reg [15:0] power_on=0;
 reg [1:0] memory_reset=3,cpu_reset=3;
 always @(posedge clk or negedge locked) begin
  if(!locked) begin power_on<=0;memory_reset<=3;end
  else begin
   if(!(&power_on)) power_on<=power_on+1'b1;
   if(!(&power_on))memory_reset<=3;else memory_reset<={memory_reset[0],1'b0};
  end
 end
 always @(posedge clk or negedge KEY[0]) begin
  if(!KEY[0]) cpu_reset<=3;
  else if(memory_reset[1])cpu_reset<=3;else cpu_reset<={cpu_reset[0],1'b0};
 end
 wire [479:0] jtag_source;wire [95:0] jtag_probe;
 altsource_probe #(.instance_id("DOOM6"),.source_width(480),.probe_width(96),
 .sld_auto_instance_index("NO"),.sld_instance_index(0),.source_initial_value("0"),.enable_metastability("NO"))
 host(.source(jtag_source),.probe(jtag_probe),.source_clk(clk),.source_ena(1'b1));
 wire [9:0] red,green,blue;
 phase7_soc #(.CACHE_ENABLE(0),.ROM_FILE("../../phase6/firmware/boot.hex")) soc(.clk(clk),.rst(cpu_reset[1]),.memory_rst(memory_reset[1]),
 .jtag_source(jtag_source),.jtag_probe(jtag_probe),.ps2_clk(PS2_CLK),.ps2_data(PS2_DAT),.pixel_clk(),.hs(VGA_HS),.vs(VGA_VS),.blank(),
 .red(red),.green(green),.blue(blue),.halted(LEDR[0]),.cause(),.debug_pc(),.mailbox(),.frames(),
 .dram_addr(DRAM_ADDR),.dram_ba(DRAM_BA),.dram_dqm(DRAM_DQM),.dram_cke(DRAM_CKE),
 .dram_cs_n(DRAM_CS_N),.dram_ras_n(DRAM_RAS_N),.dram_cas_n(DRAM_CAS_N),.dram_we_n(DRAM_WE_N),.dram_dq(DRAM_DQ));
 assign VGA_R=red[9:6];assign VGA_G=green[9:6];assign VGA_B=blue[9:6];
endmodule
