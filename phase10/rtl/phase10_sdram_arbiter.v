`timescale 1ns/1ps
// Four video grants then one waiting CPU grant. Ownership is latched until
// completion; the controller sees a full low-valid rearm cycle between words.
module phase10_sdram_arbiter(
 output video_busy,input clk,rst,
 input c_valid,c_fetch,input [31:0] c_addr,c_wdata,input [3:0] c_wstrb,input [1:0] c_size,
 output c_ready,c_error,output [31:0] c_rdata,
 input v_valid,input [31:0] v_addr,output v_ready,v_error,output [31:0] v_rdata,
 output m_valid,m_fetch,output [31:0] m_addr,m_wdata,output [3:0] m_wstrb,output [1:0] m_size,
 input m_ready,m_error,input [31:0] m_rdata,
 output reg [31:0] video_words,cpu_words,max_video_wait
);
 
 localparam IDLE=0,ACTIVE=1,GAP=2;
 reg [1:0] state;reg owner;reg [2:0] quota;
 assign video_busy=state==1 && owner;
 reg fetch;reg [31:0] addr,data;reg [3:0] strobes;reg [1:0] size;
 reg [31:0] wait_count;
 assign m_valid=state==ACTIVE;assign m_fetch=fetch;assign m_addr=addr;
 assign m_wdata=data;assign m_wstrb=strobes;assign m_size=size;
 assign c_ready=m_valid && !owner && m_ready;
 assign v_ready=m_valid && owner && m_ready;
 assign c_error=m_error;assign v_error=m_error;assign c_rdata=m_rdata;assign v_rdata=m_rdata;
 always @(posedge clk) begin
  if(rst)begin state<=IDLE;owner<=0;quota<=0;fetch<=0;addr<=0;data<=0;strobes<=0;size<=2;
   video_words<=0;cpu_words<=0;wait_count<=0;max_video_wait<=0;end
  else begin
   if(!v_valid || v_ready) wait_count<=0;else wait_count<=wait_count+1'b1;
   if(wait_count>max_video_wait)max_video_wait<=wait_count;
   case(state)
    IDLE: if(v_valid || c_valid)begin
     state<=ACTIVE;
     if(v_valid && (!c_valid || quota<4))begin owner<=1;addr<=v_addr;data<=0;strobes<=0;size<=2;fetch<=0;
      if(quota<4)quota<=quota+1'b1;end
     else begin owner<=0;addr<=c_addr;data<=c_wdata;strobes<=c_wstrb;size<=c_size;fetch<=c_fetch;quota<=0;end
    end
    ACTIVE: if(m_ready)begin state<=GAP;if(owner)video_words<=video_words+1'b1;else cpu_words<=cpu_words+1'b1;end
    GAP:state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
