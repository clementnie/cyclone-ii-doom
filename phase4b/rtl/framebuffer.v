`timescale 1ns/1ps
module framebuffer(
 input clk,rst,input enable_request,slot_request,
 input pal_we,input [7:0] pal_addr,input [11:0] pal_data,
 output reg dma_valid,output wire [31:0] dma_addr,
 input dma_ready,dma_error,input [31:0] dma_data,
 output reg active,active_slot,output wire pending,
 output reg [31:0] underflows,frames,
 output wire pixel_clk,output reg hs,vs,blank,output reg [11:0] rgb,
 output reg [9:0] scan_x,scan_y
);
 reg phase;reg [9:0] x,y;
 reg [31:0] line0[0:79],line1[0:79];
 reg [31:0] line_q;
 reg [11:0] palette[0:255],palette_q;
 reg [7:0] tag0,tag1,fetch_row;
 reg valid0,valid1,fetch_bank,busy;
 reg [6:0] word_index;
 reg [31:0] row_address;
 reg [7:0] next_row;
 wire in_band=y>=40 && y<440;
 wire [8:0] source_y=(y-10'd40)>>1;
 wire bank=source_y[0];
 wire line_good=bank?(valid1 && tag1==source_y[7:0]):(valid0 && tag0==source_y[7:0]);
 wire [6:0] read_word=x[9:3];
 wire [1:0] read_byte=x[2:1];
 reg [1:0] byte1;
 reg [9:0] x1,x2,y1,y2;
 reg ce1,ce2,h1,h2,v1,v2,b1,b2,good1,good2;
 wire [7:0] index=line_q >> {byte1,3'b000};
 assign dma_addr=row_address+{23'b0,word_index,2'b00};
 assign pending=slot_request!=active_slot;
 assign pixel_clk=phase;
 // Two explicit synchronous RAM stages, followed by registered DAC outputs.
 always @(posedge clk)begin
  if(dma_valid && dma_ready && !dma_error)begin
   if(fetch_bank)line1[word_index]<=dma_data;else line0[word_index]<=dma_data;
  end
  if(read_word<80)begin
   if(bank)line_q<=line1[read_word];else line_q<=line0[read_word];
  end
  if(pal_we)palette[pal_addr]<=pal_data;
  palette_q<=palette[index];
 end
 always @(posedge clk)begin
  if(rst)begin
   phase<=0;x<=0;y<=0;active<=0;active_slot<=0;frames<=0;underflows<=0;
   valid0<=0;valid1<=0;tag0<=0;tag1<=0;fetch_row<=0;fetch_bank<=0;busy<=0;
   word_index<=0;row_address<=0;dma_valid<=0;next_row<=0;
   scan_x<=0;scan_y<=0;x1<=0;x2<=0;y1<=0;y2<=0;byte1<=0;ce1<=0;ce2<=0;h1<=1;h2<=1;v1<=1;v2<=1;b1<=0;b2<=0;good1<=0;good2<=0;
   hs<=1;vs<=1;blank<=0;rgb<=0;
  end else begin
   phase<=~phase;
   x1<=x;x2<=x1;y1<=y;y2<=y1;ce1<=phase;ce2<=ce1;byte1<=read_byte;
   h1<=!(x>=656 && x<752);h2<=h1;v1<=!(y>=490 && y<492);v2<=v1;
   b1<=x<640 && y<480;b2<=b1;
   good1<=active && x<640 && in_band && line_good;good2<=good1;
   if(ce2)begin scan_x<=x2;scan_y<=y2;hs<=h2;vs<=v2;blank<=b2;rgb<=good2?palette_q:12'b0;end
   if(dma_valid && dma_ready)begin
    dma_valid<=0;
    if(dma_error)begin busy<=0;underflows<=underflows+1'b1;end
    else if(word_index==79)begin
     busy<=0;
     if(fetch_bank)begin valid1<=1;tag1<=fetch_row;end
     else begin valid0<=1;tag0<=fetch_row;end
    end else word_index<=word_index+1'b1;
   end else if(busy && !dma_valid)dma_valid<=1;
   if(phase)begin
    if(x==799)begin x<=0;if(y==524)begin y<=0;frames<=frames+1'b1;end else y<=y+1'b1;end
    else x<=x+1'b1;
    if(x==0 && y==520)begin active<=enable_request;active_slot<=slot_request;valid0<=0;valid1<=0;next_row<=0;end
    // Fetch row 0 in the top border. Then fetch row n+1 as row n starts.
    if(active && x==0 && (y==38 || (y>=40 && y<438 && !y[0])))begin
     if(busy)underflows<=underflows+1'b1;
     else begin
      busy<=1;dma_valid<=1;word_index<=0;fetch_row<=next_row;fetch_bank<=next_row[0];
      row_address<=(active_slot?32'h20010000:32'h20000000)+({24'b0,next_row}<<8)+({24'b0,next_row}<<6);
      if(next_row[0])valid1<=0;else valid0<=0;
      next_row<=next_row+1'b1;
     end
    end
    if(active && x==0 && y>=40 && y<440 && !y[0] && !line_good)underflows<=underflows+1'b1;
   end
  end
 end
endmodule
