`timescale 1ns/1ps
module phase10_soc #(parameter OPEN_PAGE=1,parameter CACHE_ENABLE=1,parameter ROM_FILE="firmware/boot.hex")(
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
 wire valid,fetch,ready,error,retired;wire refresh_busy,video_busy,row_hit_event,row_miss_event;wire [31:0] perf_underflows;
 wire [31:0] fabric_addr,fabric_wdata;wire fabric_fetch;wire [3:0] fabric_wstrb;wire [1:0] fabric_size;
 wire fabric_valid,cache_ready,cache_error,hit_event,miss_event;wire [31:0] cache_data;
 wire [95:0] loader_probe,perf_probe;wire perf_selected;wire [31:0] perf_command,perf_selector,refresh_count;
 assign jtag_probe=perf_selected?perf_probe:loader_probe;
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
 instruction_cache #(.ENABLE(CACHE_ENABLE)) icache(.clk(clk),.rst(rst),.c_valid(valid),.c_fetch(fetch),.c_addr(addr),.c_wdata(wdata),.c_wstrb(wstrb),.c_size(size),.c_ready(cache_ready),.c_error(cache_error),.c_rdata(cache_data),
 .m_valid(fabric_valid),.m_fetch(fabric_fetch),.m_addr(fabric_addr),.m_wdata(fabric_wdata),.m_wstrb(fabric_wstrb),.m_size(fabric_size),.m_ready(response_ready),.m_error(response_error),.m_rdata(response_data),.hit_event(hit_event),.miss_event(miss_event));
 performance counters(.clk(clk),.rst(rst),.command(perf_command),.selector(perf_selector),.selected(perf_selected),.probe(perf_probe),
 .valid(valid),.fetch(fetch),.ready(cache_ready),.retired(retired),.addr(addr),.pc(debug_pc),.wstrb(wstrb),.memory_valid(m_valid),.memory_ready(m_ready),.memory_wstrb(m_wstrb),
 .refresh_busy(refresh_busy),
 .refresh_count(refresh_count),.underflows(perf_underflows),.engine_frames(mailbox),.hit_event(hit_event),.miss_event(miss_event),
 .vga_contention(video_busy),.activate({dram_ras_n,dram_cas_n,dram_we_n}==3'b011),.column({dram_ras_n,dram_cas_n}==2'b10),.row_hit_event(row_hit_event),.row_miss_event(row_miss_event));
 phase10_sdram_arbiter arbiter(.video_busy(video_busy),.clk(clk),.rst(memory_rst),.c_valid(ext_valid && !rst),.c_fetch(fabric_fetch),
 .c_addr(fabric_addr),.c_wdata(fabric_wdata),.c_wstrb(fabric_wstrb),.c_size(fabric_size),.c_ready(ext_ready),.c_error(ext_error),.c_rdata(ext_data),
 .v_valid(dma_valid),.v_addr(dma_addr),.v_ready(dma_ready),.v_error(dma_error),.v_rdata(dma_data),
 .m_valid(m_valid),.m_fetch(m_fetch),.m_addr(m_addr),.m_wdata(m_wdata),.m_wstrb(m_wstrb),.m_size(m_size),
 .m_ready(m_ready),.m_error(m_error),.m_rdata(m_rdata),.video_words(video_words),.cpu_words(cpu_words),.max_video_wait(max_video_wait));
 phase10_sdram_controller #(.OPEN_PAGE(OPEN_PAGE)) external_memory(.row_hit_event(row_hit_event),.row_miss_event(row_miss_event),.refresh_busy(refresh_busy),.clk(clk),.rst(memory_rst),.valid(m_valid),.fetch(m_fetch),
 .addr(m_addr),.wdata(m_wdata),.wstrb(m_wstrb),.size(m_size),.ready(m_ready),.error(m_error),.rdata(m_rdata),
 .initialized(),.refresh_count(refresh_count),.dram_addr(dram_addr),.dram_ba(dram_ba),.dram_cke(dram_cke),
 .dram_cs_n(dram_cs_n),.dram_ras_n(dram_ras_n),.dram_cas_n(dram_cas_n),.dram_we_n(dram_we_n),
 .dram_dqm(dram_dqm),.dram_dq(dram_dq));
 rv32i_cpu cpu(.clk(clk),.rst(rst),.valid(valid),.fetch(fetch),.addr(addr),.wdata(wdata),
  .wstrb(wstrb),.size(size),.ready(cache_ready),.error(cache_error),.rdata(cache_data),
  .halted(halted),.cause(cause),.fault_pc(),.fault_value(),.debug_pc(debug_pc),.retired(retired));
 phase10_bus #(.ROM_FILE(ROM_FILE)) fabric(.perf_underflows(perf_underflows),.jtag_source(jtag_source),.jtag_probe(loader_probe),.perf_command(perf_command),.perf_selector(perf_selector),.dma_valid(dma_valid),.dma_addr(dma_addr),.dma_ready(dma_ready),.dma_error(dma_error),.dma_data(dma_data),
 .video_words(video_words),.cpu_words(cpu_words),.max_video_wait(max_video_wait),.ext_ready(ext_ready),.ext_error(ext_error),.ext_data(ext_data),.ext_valid(ext_valid),.cpu_halted(halted),.cpu_cause(cause),.clk(clk),.rst(rst),.valid(fabric_valid),.fetch(fabric_fetch),
  .addr(fabric_addr),.wdata(fabric_wdata),.wstrb(fabric_wstrb),.size(fabric_size),.ready(ready),.error(error),.rdata(rdata),
  .ps2_clk(ps2_clk),.ps2_data(ps2_data),.pixel_clk(pixel_clk),.hs(hs),.vs(vs),.blank(blank),
  .red(red),.green(green),.blue(blue),.frames(frames),.mailbox(mailbox));
endmodule
