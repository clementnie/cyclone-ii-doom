`timescale 1ns/1ps
// 50 MHz, x16 SDR SDRAM, 4 banks x 4096 rows x 256 columns.
// Single client, closed page, BL=1 CL=2. Commands launch on clk rising;
// the forwarded SDRAM clock rises 8 ns later. No asynchronous data crossing.
// PSC A2V64S40CTP-G7: 21ns tRP/tRCD, 70ns refresh, 8 initialization refreshes.
module phase7_sdram_controller #(parameter POWER_CYCLES=10000, REFRESH_CYCLES=700)(
 output wire refresh_busy,
 input wire clk,rst,valid,fetch,
 input wire [31:0] addr,wdata, input wire [3:0] wstrb,
 input wire [1:0] size,
 output reg ready,error, output reg [31:0] rdata,
 output reg initialized, output reg [31:0] refresh_count,
 output reg [11:0] dram_addr, output reg [1:0] dram_ba,
 output wire dram_cke, output wire dram_cs_n,
 output wire dram_ras_n,dram_cas_n,dram_we_n,
 output reg [1:0] dram_dqm, inout wire [15:0] dram_dq
);
 
 localparam BOOT=0,IPRE=1,IREF1=2,IREF2=3,MODE=4,IDLE=5,
 ACT=6,COLUMN=7,CAPTURE=8,PRE=9,DONE=10,REFRESH=11,WAIT=12;
 reg [3:0] state,next_state;
 assign refresh_busy=state==11 || (state==12 && next_state==5);
 localparam [14:0] POWER_WAIT=POWER_CYCLES-1;
 reg [14:0] delay_count;
 reg [9:0] refresh_timer;
 reg served,half,writing,drive;
 reg [3:0] init_refreshes;
 reg [22:0] saved_addr;
 reg [31:0] saved_data;
 reg [3:0] saved_strobes;
 reg [15:0] dq_out;
 reg [15:0] dq_input;
 always @(posedge clk) dq_input<=dram_dq;
 reg [2:0] cmd;
 assign {dram_ras_n,dram_cas_n,dram_we_n}=cmd;
 assign dram_cs_n=1'b0;
 assign dram_cke=1'b1;
 assign dram_dq=drive?dq_out:16'bz;
 wire bad=addr<32'h20000000 || addr>=32'h20800000 || size==3 ||
   (size==2 && addr[1:0]!=0) || (size==1 && addr[0]) || (fetch && |wstrb) ||
   (|wstrb && wstrb!=((size==0?4'b0001:size==1?4'b0011:4'b1111)<<addr[1:0]));
 always @(posedge clk) begin
  if(rst) begin
   state<=BOOT; next_state<=IPRE; delay_count<=POWER_WAIT;
   ready<=0; error<=0; rdata<=0; initialized<=0; refresh_count<=0;
   refresh_timer<=0; init_refreshes<=0; served<=0; half<=0; writing<=0; drive<=0;
   saved_addr<=0; saved_data<=0; saved_strobes<=0;
   dq_out<=0; cmd<=3'b111; dram_addr<=0; dram_ba<=0; dram_dqm<=3;
  end else begin
   cmd<=3'b111; drive<=0; dram_dqm<=initialized?2'b00:2'b11; ready<=0;
   if(!valid) served<=0;
   if(initialized && refresh_timer<REFRESH_CYCLES) refresh_timer<=refresh_timer+1'b1;
   case(state)
    BOOT,WAIT: if(delay_count!=0) delay_count<=delay_count-1'b1; else state<=next_state;
    IPRE: begin cmd<=3'b010; dram_addr<=12'h400; state<=WAIT; delay_count<=2; next_state<=IREF1; end
    IREF1: begin cmd<=3'b001; state<=WAIT; delay_count<=4;
     init_refreshes<=init_refreshes+1'b1;
     next_state<=init_refreshes==7?MODE:IREF1; end
    IREF2: begin cmd<=3'b001; state<=WAIT; delay_count<=4; next_state<=MODE; end
    MODE: begin cmd<=3'b000; dram_addr<=12'h020; dram_ba<=0;
     state<=WAIT; delay_count<=2; next_state<=IDLE; initialized<=1; refresh_timer<=0; end
    IDLE: begin
     if(refresh_timer>=REFRESH_CYCLES) state<=REFRESH;
     else if(valid && !served) begin
      served<=1; error<=bad;
      if(bad) begin ready<=1; rdata<=0; end
      else begin saved_addr<=addr[22:0]; saved_data<=wdata; saved_strobes<=wstrb;
       half<=0; writing<=|wstrb; state<=ACT; end
     end
    end
    ACT: begin cmd<=3'b011; dram_addr<=saved_addr[20:9]; dram_ba<=saved_addr[22:21];
     state<=WAIT; delay_count<=2; next_state<=COLUMN; end
    COLUMN: begin
     dram_addr<={4'b0,saved_addr[8:2],half}; // aligned 32-bit word -> two x16 locations
     if(writing) begin cmd<=3'b100; drive<=1;
      dq_out<=half?saved_data[31:16]:saved_data[15:0];
      dram_dqm<=~(half?saved_strobes[3:2]:saved_strobes[1:0]);
      state<=WAIT; delay_count<=2; next_state<=CAPTURE;
     end else begin cmd<=3'b101; state<=WAIT; delay_count<=2; next_state<=CAPTURE; end
    end
    CAPTURE: begin
     if(!writing) begin
      if(half) rdata[31:16]<=dq_input; else rdata[15:0]<=dq_input;
     end
     if(!half) begin half<=1; state<=COLUMN; end else state<=PRE;
    end
    PRE: begin cmd<=3'b010; dram_addr<=12'h400; state<=WAIT; delay_count<=2; next_state<=DONE; end
    DONE: begin ready<=1; state<=IDLE; end
    REFRESH: begin cmd<=3'b001; refresh_count<=refresh_count+1'b1; refresh_timer<=0;
     state<=WAIT; delay_count<=4; next_state<=IDLE; end
    default: state<=BOOT;
   endcase
  end
 end
endmodule
