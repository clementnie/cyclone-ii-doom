`timescale 1ns/1ps
module onchip_memory #(parameter ROM_FILE="firmware/boot.hex")(
 input wire clk, rst, valid, fetch, input wire [31:0] addr,wdata,
 input wire [3:0] wstrb, output reg ready, error, output wire [31:0] rdata
);
 // Synchronous read, byte write enables, no reset of memory arrays.
 reg [31:0] rom[0:2047];
 reg [31:0] ram[0:2047];
 reg [31:0] rom_q, ram_q;
 reg select_ram, served;
 wire rom_hit=addr<32'h00002000;
 wire ram_hit=addr>=32'h00010000 && addr<32'h00012000;
 integer lane;
 initial $readmemh(ROM_FILE,rom);
 assign rdata=select_ram?ram_q:rom_q;
 always @(posedge clk) begin
  rom_q<=rom[addr[12:2]];
  ram_q<=ram[addr[12:2]];
  if(valid && !served && !rst && ram_hit && !fetch)
   for(lane=0;lane<4;lane=lane+1)
    if(wstrb[lane]) ram[addr[12:2]][lane*8+:8]<=wdata[lane*8+:8];
  if(rst) begin ready<=0; error<=0; served<=0; select_ram<=0; end
  else begin
   ready<=0;
   if(!valid) served<=0;
   else if(!served) begin
    served<=1; ready<=1; select_ram<=ram_hit;
    error<=(!rom_hit && !ram_hit) || (rom_hit && |wstrb) || (fetch && |wstrb);
   end
  end
 end
endmodule
