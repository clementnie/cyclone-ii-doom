`timescale 1ns/1ps
module full_top #(parameter OPEN_PAGE=1,parameter CACHE_ENABLE=1)(input clk,rst,input [479:0] source,output [95:0] probe,
 input dq_oe,input [15:0] dq_in,output [15:0] dq_out,output [11:0] a,
 output [1:0] ba,dqm,output cke,cs,ras,cas,we,
 output req_valid,req_ready,req_fetch,req_error,output [31:0] req_addr,output [3:0] req_strobes,
 output [1023:0] perf,output halted,output [3:0] cause,output [31:0] pc,sp,fault_pc,fault_value,hb,frames,
 output [11:0] rgb,output pixel,hs,vs,blank,output [9:0] x,y,
 output [31:0] underflows,diag,heap_high,output retired,output [31:0] game_renders);
 wire [15:0] dq;assign dq=dq_oe?dq_in:16'bz;assign dq_out=dq;
 wire [9:0] r,g,b;
 phase10_soc #(.OPEN_PAGE(OPEN_PAGE),.CACHE_ENABLE(CACHE_ENABLE),.ROM_FILE("phase6/firmware/boot.hex")) dut(.clk(clk),.rst(rst),.memory_rst(rst),
 .jtag_source(source),.jtag_probe(probe),.ps2_clk(1'b1),.ps2_data(1'b1),
 .dram_addr(a),.dram_ba(ba),.dram_dqm(dqm),.dram_cke(cke),.dram_cs_n(cs),.dram_ras_n(ras),.dram_cas_n(cas),.dram_we_n(we),.dram_dq(dq),
 .pixel_clk(pixel),.hs(hs),.vs(vs),.blank(blank),.red(r),.green(g),.blue(b),.halted(halted),.cause(cause),.debug_pc(pc),.mailbox(hb),.frames(frames));
 assign req_valid=dut.valid;assign req_ready=dut.cache_ready;assign req_fetch=dut.fetch;assign req_addr=dut.addr;assign req_strobes=dut.wstrb;assign req_error=dut.cache_error;
 assign rgb={r[9:6],g[9:6],b[9:6]};
 assign sp=dut.cpu.regs[2];assign fault_pc=dut.cpu.fault_pc;assign fault_value=dut.cpu.fault_value;
 assign retired=dut.retired;assign diag=dut.fabric.diag_error;
 assign x=dut.fabric.pixels.scan_x;assign y=dut.fabric.pixels.scan_y;
 assign underflows=dut.fabric.underflows;
 assign heap_high=0;assign game_renders=dut.fabric.key_status;
 genvar i;generate for(i=0;i<32;i=i+1)begin assign perf[32*i+:32]=dut.counters.live[i];end endgenerate
endmodule
