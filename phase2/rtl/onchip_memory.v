`timescale 1ns/1ps
module onchip_memory #(parameter ROM_FILE="firmware/boot.hex")(
 input wire clk, rst, valid, fetch, input wire [31:0] addr,wdata,
 input wire [3:0] wstrb, output reg ready, error, output wire [31:0] rdata
);
 // Synchronous read, byte write enables, no reset of memory arrays.
 reg [31:0] rom[0:2047];
 // Independent byte lanes retain little-endian ordering and old-data reads.
 reg [7:0] ram0[0:2047];
 reg [7:0] ram1[0:2047];
 reg [7:0] ram2[0:2047];
 reg [7:0] ram3[0:2047];
 reg [31:0] rom_q, ram_q;
 reg select_ram, served;
 wire rom_hit=addr<32'h00002000;
 wire ram_hit=addr>=32'h00010000 && addr<32'h00012000;
 initial $readmemh(ROM_FILE,rom);
 assign rdata=select_ram?ram_q:rom_q;
 always @(posedge clk) begin
  rom_q<=rom[addr[12:2]];
  ram_q<={ram3[addr[12:2]],ram2[addr[12:2]],
          ram1[addr[12:2]],ram0[addr[12:2]]};
  if(valid && !served && !rst && ram_hit && !fetch) begin
   if(wstrb[0]) ram0[addr[12:2]]<=wdata[7:0];
   if(wstrb[1]) ram1[addr[12:2]]<=wdata[15:8];
   if(wstrb[2]) ram2[addr[12:2]]<=wdata[23:16];
   if(wstrb[3]) ram3[addr[12:2]]<=wdata[31:24];
  end
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
