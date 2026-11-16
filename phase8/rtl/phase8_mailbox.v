`timescale 1ns/1ps
// Host holds bundled source data until CPU ACK; command is synchronized,
// then delayed two further clocks before the stable payload is captured.
module phase8_mailbox(input clk,rst,input [479:0] source,
 output [95:0] probe,output [31:0] command,selector,input valid,fetch,input [31:0] addr,wdata,
 input [3:0] wstrb,input [1:0] size,output ready,error,output reg [31:0] rdata);
 (* preserve, altera_attribute = "-name DONT_MERGE_REGISTER ON; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg [31:0] cmd_meta,cmd_sync;
 reg [31:0] cmd_delay,cmd_stable;
 reg [479:0] payload;
 reg [31:0] ack,result,status;
 reg served;
 wire accept=valid&&!served&&!rst;
 wire ok=!fetch&&size==2&&addr[1:0]==0;
 wire writable=addr[7:0]==8'h40||addr[7:0]==8'h44||addr[7:0]==8'h48;
 assign ready=valid&&!served&&!rst;
 assign error=!ok||((|wstrb)&&(!writable||wstrb!=15))||addr[11:8]!=0||addr[7:0]>8'h48||
               (addr[7:0]>=8'h3c&&addr[7:0]<8'h40);
 assign probe={status,result,ack};
 assign command=payload[31:0];assign selector=payload[63:32];
 always @* begin
  rdata=0;
  if(addr[7:0]<8'h3c)rdata=payload[addr[7:2]*32+:32];
  else case(addr[7:0])8'h40:rdata=result;8'h44:rdata=ack;8'h48:rdata=status;endcase
 end
 always @(posedge clk)begin
  cmd_meta<=source[31:0];cmd_sync<=cmd_meta;cmd_delay<=cmd_sync;cmd_stable<=cmd_delay;
  if(rst)begin payload<=0;ack<=0;result<=0;status<=0;served<=0;end
  else begin
   if(cmd_stable==cmd_delay && cmd_stable!=payload[31:0])payload<=source;
   if(!valid)served<=0;else if(ready)served<=1;
   if(accept&&!error&&wstrb==15)case(addr[7:0])8'h40:result<=wdata;8'h44:ack<=wdata;8'h48:status<=wdata;endcase
  end
 end
endmodule
