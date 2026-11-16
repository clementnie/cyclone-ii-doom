`timescale 1ns/1ps
module tb_performance;
 reg clk=0;always #10 clk=~clk;
 reg rst=1;reg [31:0] command=0,selector=0,addr=0,pc=0,refresh_count=0,underflows=0,engine_frames=0;
 reg valid=0,fetch=0,ready=0,retired=0,memory_valid=0,memory_ready=0,refresh_busy=0,vga_contention=0,hit_event=0,miss_event=0,activate=0,column=0;
 reg [3:0] wstrb=0,memory_wstrb=0;wire selected;wire [95:0] probe;
 wire row_hit_event=0,row_miss_event=0;
 performance dut(.*);
 reg [31:0] frozen;
 initial begin
 repeat(4)@(negedge clk);rst=0;
 valid=1;fetch=1;repeat(7)@(negedge clk);ready=1;@(negedge clk);valid=0;ready=0;retired=1;@(negedge clk);retired=0;
 command=32'h7e000001;repeat(2)@(negedge clk);
 if(probe[31:0]!==command||probe[95:64]!==32'hd8000001)$fatal(1,"snapshot ACK");frozen=probe[63:32];
 repeat(10)@(negedge clk);if(probe[63:32]!==frozen)$fatal(1,"snapshot not frozen");
 selector=2;command=32'h7f000002;repeat(2)@(negedge clk);if(probe[63:32]!==1)$fatal(1,"fetch duplicate");
 selector=3;command=32'h7f000003;repeat(2)@(negedge clk);if(probe[63:32]!==7)$fatal(1,"fetch stall count");
 selector=1;command=32'h7f000004;repeat(2)@(negedge clk);if(probe[63:32]!==1)$fatal(1,"retirement count");
 selector=0;command=32'h7e000005;repeat(2)@(negedge clk);if(probe[63:32]<=frozen)$fatal(1,"live stopped");
 $display("PASS performance: retirement, request dedup, exact fetch stalls, atomic frozen snapshots, live counting, selector ACK");$finish;
 end
endmodule
