`timescale 1ns/1ps
module tb_mailbox;
 reg clk=0;always #10 clk=~clk;
 reg rst=1;reg [479:0] source=0;wire [95:0] probe;
 reg valid=0,fetch=0;reg [31:0] addr=0,wdata=0;reg [3:0] wstrb=0;reg [1:0] size=2;
 wire ready,error;wire [31:0] rdata;
 jtag_mailbox dut(.*);
 task read(input [31:0] a,expected);
 begin @(negedge clk);addr=a;valid=1;#1;if(!ready||error||rdata!==expected)$fatal(1,"read %h got %h wanted %h",a,rdata,expected);
 @(negedge clk);if(ready)$fatal(1,"duplicate response");valid=0;@(negedge clk);end endtask
 task write(input [31:0] a,d);
 begin @(negedge clk);addr=a;wdata=d;wstrb=15;valid=1;#1;if(!ready||error)$fatal(1,"write error");
 @(negedge clk);valid=0;wstrb=0;@(negedge clk);end endtask
 integer i;
 initial begin
 repeat(3)@(negedge clk);rst=0;
 // Change the bundled source off-clock. It must remain unchanged until ACK.
 #7;source[31:0]=32'h03001234;source[63:32]=32'h20380000;
 for(i=0;i<13;i=i+1)source[64+i*32+:32]=32'h01234567+i;
 repeat(8)@(negedge clk);
 read(0,32'h03001234);read(4,32'h20380000);
 for(i=0;i<13;i=i+1)read(8+i*4,32'h01234567+i);
 write(64,32'hcafebabe);write(72,32'hd6000003);write(68,32'h03001234);
 if(probe!==96'hd6000003cafebabe03001234)$fatal(1,"probe mismatch");
 @(negedge clk);addr=60;valid=1;#1;if(!error)$fatal(1,"reserved offset");valid=0;
 @(negedge clk);addr=0;valid=1;wstrb=15;#1;if(!error)$fatal(1,"source is read-only");valid=0;wstrb=0;
 @(negedge clk);addr=64;valid=1;fetch=1;#1;if(!error)$fatal(1,"fetch forbidden");valid=0;fetch=0;
 @(negedge clk);rst=1;@(negedge clk);rst=0;
 repeat(8)@(negedge clk);read(0,32'h03001234);read(68,0);
 $display("PASS mailbox: asynchronous stable bundle, 13 words, ACK/CRC/status, held request, reset, access errors");$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
