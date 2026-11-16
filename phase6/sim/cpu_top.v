module cpu_top(input clk,rst,ready,error,input [31:0] rdata,
 output valid,fetch,halted,retired,output [31:0] addr,wdata,pc,fault_pc,fault_value,sp,
 output [3:0] wstrb,cause,output [1:0] size);
 rv32i_cpu cpu(.clk(clk),.rst(rst),.ready(ready),.error(error),.rdata(rdata),
 .valid(valid),.fetch(fetch),.halted(halted),.retired(retired),.addr(addr),.wdata(wdata),
 .debug_pc(pc),.fault_pc(fault_pc),.fault_value(fault_value),.wstrb(wstrb),.cause(cause),.size(size));
 assign sp=cpu.regs[2];
endmodule
