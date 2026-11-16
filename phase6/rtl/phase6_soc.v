`timescale 1ns/1ps
module phase6_soc #(parameter ROM_FILE="firmware/boot.hex")(
 input wire clk,rst,memory_rst,ps2_clk,ps2_data,
 input wire [479:0] jtag_source,output wire [95:0] jtag_probe,
 output wire [11:0] dram_addr, output wire [1:0] dram_ba,dram_dqm,
 output wire dram_cke,dram_cs_n,dram_ras_n,dram_cas_n,dram_we_n,
 inout wire [15:0] dram_dq,
 output wire pixel_clk,hs,vs,blank,
 output wire [9:0] red,green,blue,
 output wire halted, output wire [3:0] cause,
 output wire [31:0] debug_pc,mailbox,frames
);
 wire [31:0] addr,wdata,rdata;
 wire valid,fetch,ready,error,retired;
 // Register the completed fabric response to cut the measured MMIO decode /
 // load extraction path. All slaves retain served/rearm protection.
 reg response_ready,response_error;reg [31:0] response_data;
 always @(posedge clk)begin
  if(rst)begin response_ready<=0;response_error<=0;response_data<=0;end
  else begin response_ready<=ready;response_error<=error;response_data<=rdata;end
 end
 wire [3:0] wstrb;
 wire [1:0] size;
 wire ext_valid,ext_ready,ext_error;
 wire [31:0] ext_data;
 wire dma_valid,dma_ready,dma_error,m_valid,m_fetch,m_ready,m_error;
 wire [31:0] dma_addr,dma_data,m_addr,m_wdata,m_rdata,video_words,cpu_words,max_video_wait;
 wire [3:0] m_wstrb;wire [1:0] m_size;
 sdram_arbiter arbiter(.clk(clk),.rst(memory_rst),.c_valid(ext_valid && !rst),.c_fetch(fetch),
 .c_addr(addr),.c_wdata(wdata),.c_wstrb(wstrb),.c_size(size),.c_ready(ext_ready),.c_error(ext_error),.c_rdata(ext_data),
 .v_valid(dma_valid),.v_addr(dma_addr),.v_ready(dma_ready),.v_error(dma_error),.v_rdata(dma_data),
 .m_valid(m_valid),.m_fetch(m_fetch),.m_addr(m_addr),.m_wdata(m_wdata),.m_wstrb(m_wstrb),.m_size(m_size),
 .m_ready(m_ready),.m_error(m_error),.m_rdata(m_rdata),.video_words(video_words),.cpu_words(cpu_words),.max_video_wait(max_video_wait));
 sdram_controller external_memory(.clk(clk),.rst(memory_rst),.valid(m_valid),.fetch(m_fetch),
 .addr(m_addr),.wdata(m_wdata),.wstrb(m_wstrb),.size(m_size),.ready(m_ready),.error(m_error),.rdata(m_rdata),
 .initialized(),.refresh_count(),.dram_addr(dram_addr),.dram_ba(dram_ba),.dram_cke(dram_cke),
 .dram_cs_n(dram_cs_n),.dram_ras_n(dram_ras_n),.dram_cas_n(dram_cas_n),.dram_we_n(dram_we_n),
 .dram_dqm(dram_dqm),.dram_dq(dram_dq));
 rv32i_cpu cpu(.clk(clk),.rst(rst),.valid(valid),.fetch(fetch),.addr(addr),.wdata(wdata),
  .wstrb(wstrb),.size(size),.ready(response_ready),.error(response_error),.rdata(response_data),
  .halted(halted),.cause(cause),.fault_pc(),.fault_value(),.debug_pc(debug_pc),.retired(retired));
 phase6_bus #(.ROM_FILE(ROM_FILE)) fabric(.jtag_source(jtag_source),.jtag_probe(jtag_probe),.dma_valid(dma_valid),.dma_addr(dma_addr),.dma_ready(dma_ready),.dma_error(dma_error),.dma_data(dma_data),
 .video_words(video_words),.cpu_words(cpu_words),.max_video_wait(max_video_wait),.ext_ready(ext_ready),.ext_error(ext_error),.ext_data(ext_data),.ext_valid(ext_valid),.cpu_halted(halted),.cpu_cause(cause),.clk(clk),.rst(rst),.valid(valid),.fetch(fetch),
  .addr(addr),.wdata(wdata),.wstrb(wstrb),.size(size),.ready(ready),.error(error),.rdata(rdata),
  .ps2_clk(ps2_clk),.ps2_data(ps2_data),.pixel_clk(pixel_clk),.hs(hs),.vs(vs),.blank(blank),
  .red(red),.green(green),.blue(blue),.frames(frames),.mailbox(mailbox));
endmodule
