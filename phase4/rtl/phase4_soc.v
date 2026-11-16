`timescale 1ns/1ps
module phase4_soc #(parameter ROM_FILE="firmware/boot.hex")(
 input wire clk,rst,memory_rst,ps2_clk,ps2_data,
 output wire [11:0] dram_addr, output wire [1:0] dram_ba,dram_dqm,
 output wire dram_cke,dram_cs_n,dram_ras_n,dram_cas_n,dram_we_n,
 inout wire [15:0] dram_dq,
 output wire pixel_clk,hs,vs,blank,
 output wire [9:0] red,green,blue,
 output wire halted, output wire [3:0] cause,
 output wire [31:0] debug_pc,mailbox,frames
);
 wire valid,fetch,ready,error,retired;
 wire [31:0] addr,wdata,rdata;
 wire [3:0] wstrb;
 wire [1:0] size;
 wire ext_valid,ext_ready,ext_error;
 wire [31:0] ext_data;
 sdram_controller external_memory(.clk(clk),.rst(memory_rst),.valid(ext_valid && !rst),.fetch(fetch),
 .addr(addr),.wdata(wdata),.wstrb(wstrb),.size(size),.ready(ext_ready),.error(ext_error),.rdata(ext_data),
 .initialized(),.refresh_count(),.dram_addr(dram_addr),.dram_ba(dram_ba),.dram_cke(dram_cke),
 .dram_cs_n(dram_cs_n),.dram_ras_n(dram_ras_n),.dram_cas_n(dram_cas_n),.dram_we_n(dram_we_n),
 .dram_dqm(dram_dqm),.dram_dq(dram_dq));
 rv32i_cpu cpu(.clk(clk),.rst(rst),.valid(valid),.fetch(fetch),.addr(addr),.wdata(wdata),
  .wstrb(wstrb),.size(size),.ready(ready),.error(error),.rdata(rdata),
  .halted(halted),.cause(cause),.fault_pc(),.fault_value(),.debug_pc(debug_pc),.retired(retired));
 phase4_bus #(.ROM_FILE(ROM_FILE)) fabric(.ext_ready(ext_ready),.ext_error(ext_error),.ext_data(ext_data),.ext_valid(ext_valid),.cpu_halted(halted),.cpu_cause(cause),.clk(clk),.rst(rst),.valid(valid),.fetch(fetch),
  .addr(addr),.wdata(wdata),.wstrb(wstrb),.size(size),.ready(ready),.error(error),.rdata(rdata),
  .ps2_clk(ps2_clk),.ps2_data(ps2_data),.pixel_clk(pixel_clk),.hs(hs),.vs(vs),.blank(blank),
  .red(red),.green(green),.blue(blue),.frames(frames),.mailbox(mailbox));
endmodule
