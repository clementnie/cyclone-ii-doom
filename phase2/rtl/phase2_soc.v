`timescale 1ns/1ps
module phase2_soc #(parameter ROM_FILE="firmware/boot.hex")(
 input wire clk,rst,ps2_clk,ps2_data,
 output wire pixel_clk,hs,vs,blank,
 output wire [9:0] red,green,blue,
 output wire halted, output wire [3:0] cause,
 output wire [31:0] debug_pc,mailbox,frames
);
 wire valid,fetch,ready,error,retired;
 wire [31:0] addr,wdata,rdata;
 wire [3:0] wstrb;
 wire [1:0] size;
 rv32i_cpu cpu(.clk(clk),.rst(rst),.valid(valid),.fetch(fetch),.addr(addr),.wdata(wdata),
  .wstrb(wstrb),.size(size),.ready(ready),.error(error),.rdata(rdata),
  .halted(halted),.cause(cause),.fault_pc(),.fault_value(),.debug_pc(debug_pc),.retired(retired));
 soc_bus #(.ROM_FILE(ROM_FILE)) fabric(.cpu_halted(halted),.cpu_cause(cause),.clk(clk),.rst(rst),.valid(valid),.fetch(fetch),
  .addr(addr),.wdata(wdata),.wstrb(wstrb),.size(size),.ready(ready),.error(error),.rdata(rdata),
  .ps2_clk(ps2_clk),.ps2_data(ps2_data),.pixel_clk(pixel_clk),.hs(hs),.vs(vs),.blank(blank),
  .red(red),.green(green),.blue(blue),.frames(frames),.mailbox(mailbox));
endmodule
