`timescale 1ns/1ps
// 32-byte lines; retain the Phase 9 2KiB I + 2KiB D data array.
// Write-through/no-write-allocate. No dirty state, MMIO never allocates.
module instruction_cache #(parameter ENABLE=1)(input clk,rst,
 input c_valid,c_fetch,input [31:0] c_addr,c_wdata,input [3:0] c_wstrb,input [1:0] c_size,
 output c_ready,c_error,output [31:0] c_rdata,
 output m_valid,m_fetch,output [31:0] m_addr,m_wdata,output [3:0] m_wstrb,output [1:0] m_size,
 input m_ready,m_error,input [31:0] m_rdata,output reg hit_event,miss_event);
 generate if(!ENABLE)begin
 assign m_valid=c_valid;assign m_fetch=c_fetch;assign m_addr=c_addr;assign m_wdata=c_wdata;assign m_wstrb=c_wstrb;assign m_size=c_size;
 assign c_ready=m_ready;assign c_error=m_error;assign c_rdata=m_rdata;
 always @(posedge clk)begin hit_event<=0;miss_event<=0;end
 end else begin
 reg [31:0] data[0:1023];reg [11:0] itags[0:63],dtags[0:63];reg [127:0] valid_bits;
 reg [31:0] data_q,result;reg [11:0] itag_q,dtag_q;wire [11:0] tag_q=c_fetch?itag_q:dtag_q;reg ready_q,error_q;
 reg [2:0] state,word;reg filling;
 localparam IDLE=0,LOOKUP=1,MEMORY=2,DROP=3,GAP=4,REARM=5;
 wire sdram=c_addr>=32'h20000000&&c_addr<32'h20800000;
 wire cacheable=sdram&&c_wstrb==0&&c_size!=3&&(c_size!=2||c_addr[1:0]==0)&&(c_size!=1||!c_addr[0])&&(!c_fetch || (c_size==2&&c_addr[1:0]==0));
 wire [9:0] index={c_fetch,c_addr[10:2]};
 wire [6:0] line_index={c_fetch,c_addr[10:5]};
 assign m_valid=state==MEMORY&&c_valid&&!rst;
 assign m_fetch=c_fetch;assign m_addr=filling?{c_addr[31:5],word,2'b00}:c_addr;
 assign m_wdata=c_wdata;assign m_wstrb=c_wstrb;assign m_size=filling?2'd2:c_size;
 assign c_ready=ready_q;assign c_error=error_q;assign c_rdata=result;
 always @(posedge clk)begin
  data_q<=data[index];itag_q<=itags[c_addr[10:5]];dtag_q<=dtags[c_addr[10:5]];
  if(rst)begin valid_bits<=0;state<=IDLE;ready_q<=0;error_q<=0;result<=0;hit_event<=0;miss_event<=0;word<=0;filling<=0;end
  else begin
   ready_q<=0;hit_event<=0;miss_event<=0;
   case(state)
    IDLE:if(c_valid)state<=LOOKUP;
    LOOKUP:begin
     if(sdram&&|c_wstrb)begin
      if(dtag_q==c_addr[22:11])valid_bits[{1'b0,c_addr[10:5]}]<=0;
      if(itag_q==c_addr[22:11])valid_bits[{1'b1,c_addr[10:5]}]<=0;
     end
     if(cacheable&&valid_bits[line_index]&&tag_q==c_addr[22:11])begin
      result<=data_q;error_q<=0;ready_q<=1;hit_event<=1;state<=DROP;
     end else begin
      state<=MEMORY;word<=0;filling<=cacheable;
      if(cacheable)begin miss_event<=1;valid_bits[line_index]<=0;end
     end
    end
    MEMORY:if(m_ready)begin
     if(!filling || m_error)begin
      result<=m_rdata;error_q<=m_error;ready_q<=1;state<=DROP;
     end else begin
      data[{c_fetch,c_addr[10:5],word}]<=m_rdata;
      if(word==c_addr[4:2])result<=m_rdata;
      if(word==7)begin
       if(c_fetch)itags[c_addr[10:5]]<=c_addr[22:11];else dtags[c_addr[10:5]]<=c_addr[22:11];valid_bits[line_index]<=1;
       error_q<=0;ready_q<=1;state<=DROP;
      end else begin word<=word+1'b1;state<=GAP;end
     end
    end
    GAP:state<=REARM;
    REARM:state<=MEMORY;
    DROP:if(!c_valid)state<=IDLE;
   endcase
  end
 end
 end endgenerate
endmodule
