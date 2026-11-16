`timescale 1ns/1ps
// One-word lines, 2 KiB instruction + 2 KiB data, direct mapped, write through.
// Synchronous tag/data reads infer M4K. Matching CPU stores invalidate before
// reaching memory. DMA is read-only. Reset discards all cached instructions.
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
 reg [31:0] data[0:1023];reg [11:0] tags[0:1023];reg [1023:0] valid_bits;
 reg [31:0] data_q,result;reg [11:0] tag_q;reg ready_q,error_q;
 reg [1:0] state;localparam IDLE=0,LOOKUP=1,MEMORY=2,DROP=3;
 wire sdram=c_addr>=32'h20000000&&c_addr<32'h20800000;
 wire cacheable=sdram&&c_wstrb==0&&c_size!=3&&(c_size!=2||c_addr[1:0]==0)&&(c_size!=1||!c_addr[0])&&(!c_fetch || (c_size==2&&c_addr[1:0]==0));
 wire [9:0] index={c_fetch,c_addr[10:2]};
 assign m_valid=state==MEMORY&&c_valid&&!rst;
 assign m_fetch=c_fetch;assign m_addr=c_addr;assign m_wdata=c_wdata;assign m_wstrb=c_wstrb;assign m_size=c_size;
 assign c_ready=ready_q;assign c_error=error_q;assign c_rdata=result;
 always @(posedge clk)begin
  data_q<=data[index];tag_q<=tags[index];
  if(rst)begin valid_bits<=0;state<=IDLE;ready_q<=0;error_q<=0;result<=0;hit_event<=0;miss_event<=0;end
  else begin
   ready_q<=0;hit_event<=0;miss_event<=0;
   case(state)
    IDLE:if(c_valid)state<=LOOKUP;
    LOOKUP:begin
     if(sdram&&|c_wstrb)begin
      valid_bits[{1'b0,c_addr[10:2]}]<=0;valid_bits[{1'b1,c_addr[10:2]}]<=0;
     end
     if(cacheable&&valid_bits[index]&&tag_q==c_addr[22:11])begin
      result<=data_q;error_q<=0;ready_q<=1;hit_event<=1;state<=DROP;
     end else begin state<=MEMORY;if(cacheable)miss_event<=1;end
    end
    MEMORY:if(m_ready)begin
     result<=m_rdata;error_q<=m_error;ready_q<=1;state<=DROP;
     if(cacheable&&!m_error)begin data[index]<=m_rdata;tags[index]<=c_addr[22:11];valid_bits[index]<=1;end
    end
    DROP:if(!c_valid)state<=IDLE;
   endcase
  end
 end
 end endgenerate
endmodule
