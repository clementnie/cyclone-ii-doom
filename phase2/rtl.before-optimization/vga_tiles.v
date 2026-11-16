`timescale 1ns/1ps
module vga_tiles(
 input wire clk, rst,
 input wire [1:0] mode, input wire [7:0] color,
 input wire tile_we, input wire [10:0] tile_addr, input wire [7:0] tile_data,
 output wire pixel_clk, output reg hs,vs,blank,
 output reg [9:0] red,green,blue,
 output reg [31:0] frames,
 output wire [9:0] scan_x, scan_y
);
 reg phase;
 reg [9:0] x,y;
 reg [7:0] tiles[0:2047];
 reg [7:0] tile_q;
 wire [10:0] row={6'b0,y[8:4]};
 wire [10:0] read_addr=(row<<5)+(row<<3)+{5'b0,x[9:4]};
 reg [7:0] rgb;
 assign pixel_clk=phase;
 assign scan_x=x; assign scan_y=y;
 always @* begin
  case(mode)
   1: rgb=color;
   2: rgb=tile_q;
   default: rgb={x[7:5],y[7:5],x[9:8]};
  endcase
 end
 // Independent synchronous read and write ports infer simple dual-port RAM.
 always @(posedge clk) begin
  if(tile_we) tiles[tile_addr]<=tile_data;
  tile_q<=tiles[read_addr];
 end
 always @(posedge clk) begin
  if(rst) begin
   phase<=0; x<=0; y<=0; frames<=0;
   hs<=1; vs<=1; blank<=0; red<=0; green<=0; blue<=0;
  end else begin
   phase<=!phase;
   if(phase) begin // launch on falling DAC clock, sample 20 ns later
    hs<=!(x>=656 && x<752); vs<=!(y>=490 && y<492);
    blank<=x<640 && y<480;
    if(x<640 && y<480) begin
     red<={rgb[7:5],rgb[7:5],rgb[7:5],rgb[7]};
     green<={rgb[4:2],rgb[4:2],rgb[4:2],rgb[4]};
     blue<={rgb[1:0],rgb[1:0],rgb[1:0],rgb[1:0],rgb[1:0]};
    end else begin red<=0; green<=0; blue<=0; end
    if(x==799) begin
     x<=0;
     if(y==524) begin y<=0; frames<=frames+1'b1; end
     else y<=y+1'b1;
    end else x<=x+1'b1;
   end
  end
 end
endmodule
