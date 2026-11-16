`timescale 1ns/1ps
// Atomic counter snapshots, selected over the existing 480/96 ISSP instance.
module performance(input clk,rst,input [31:0] command,selector,
 input valid,fetch,ready,retired,input [31:0] addr,pc,input [3:0] wstrb,
 input memory_valid,memory_ready,input [3:0] memory_wstrb,
 input refresh_busy,vga_contention,input [31:0] refresh_count,underflows,engine_frames,
 input hit_event,miss_event,input activate,column,input row_hit_event,row_miss_event,
 output selected,output [95:0] probe);
 reg [31:0] live[0:31],snap[0:31];reg seen,mem_seen;
 reg [31:0] wait_count,last_frame,last_cycle,last_retired,last_fs,last_ds,ack;
 integer i;
 assign selected=command[31:24]==8'h7e||command[31:24]==8'h7f;
 assign probe={32'hDA000001,selector<32?snap[selector[4:0]]:32'hBAD70001,ack};
 always @(posedge clk)begin
  if(rst)begin
   for(i=0;i<32;i=i+1)begin live[i]<=0;snap[i]<=0;end
   seen<=0;mem_seen<=0;wait_count<=0;last_frame<=0;last_cycle<=0;last_retired<=0;last_fs<=0;last_ds<=0;ack<=0;
  end else begin
   live[0]<=live[0]+1'b1;
   if(retired)live[1]<=live[1]+1'b1;
   if(!valid)begin seen<=0;wait_count<=0;end
   if(valid&&!seen)begin seen<=1;if(fetch)live[2]<=live[2]+1'b1;else live[24]<=live[24]+1'b1;end
   if(valid&&!ready)begin wait_count<=wait_count+1'b1;if(fetch)live[3]<=live[3]+1'b1;else live[4]<=live[4]+1'b1;end
   if(valid&&ready)begin
    if(fetch)begin live[12]<=live[12]+wait_count;if(wait_count>live[13])live[13]<=wait_count;end
    else begin live[14]<=live[14]+wait_count;if(wait_count>live[15])live[15]<=wait_count;end
    if(!fetch&&|wstrb&&addr>=32'h20000000&&addr<32'h20020000)live[8]<=live[8]+1'b1;
   end
   if(!memory_valid)mem_seen<=0;
   if(memory_valid&&!mem_seen)begin mem_seen<=1;if(|memory_wstrb)live[6]<=live[6]+1'b1;else live[5]<=live[5]+1'b1;end
   if(valid&&refresh_busy)live[7]<=live[7]+1'b1;
   live[9]<=underflows;live[10]<=engine_frames;live[19]<=refresh_count;
   if(engine_frames!=last_frame)begin
    live[11]<=live[0]-last_cycle;live[25]<=live[1]-last_retired;live[26]<=live[3]-last_fs;live[27]<=live[4]-last_ds;
    last_cycle<=live[0];last_retired<=live[1];last_fs<=live[3];last_ds<=live[4];last_frame<=engine_frames;
   end
   if(hit_event)live[16]<=live[16]+1'b1;if(miss_event)live[17]<=live[17]+1'b1;
   if(valid&&vga_contention)live[18]<=live[18]+1'b1;
   if(row_hit_event)live[28]<=live[28]+1'b1;if(row_miss_event)live[29]<=live[29]+1'b1;
   if(activate)live[20]<=live[20]+1'b1;if(column)live[21]<=live[21]+1'b1;
   // ELF-specific sampled helper entries, counted once per fetch request.
   if(valid&&fetch&&!seen&&pc==32'h200536c8)live[22]<=live[22]+1'b1;
   if(valid&&fetch&&!seen&&pc==32'h20053660)live[23]<=live[23]+1'b1;
   if(selected&&command!=ack)begin
    if(command[31:24]==8'h7e)for(i=0;i<32;i=i+1)snap[i]<=live[i];
    ack<=command;
   end
  end
 end
endmodule
