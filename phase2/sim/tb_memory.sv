`timescale 1ns/1ps
module tb_memory;
 reg clk=0; always #10 clk=~clk;
 reg rst=1,valid=0,fetch=0;
 reg [31:0] addr=0,wdata=0;
 reg [3:0] wstrb=0; reg [1:0] size=2;
 wire ready,error,pixel_clk,hs,vs,blank;
 wire [31:0] rdata,frames,mailbox;
 wire [9:0] red,green,blue;
 reg ps2_clk=1,ps2_data=1;
 wire cpu_halted=0; wire [3:0] cpu_cause=0;
 soc_bus dut(.*);
 integer checks=0,i;
 reg [31:0] value;
 task access(input [31:0] address,data,input [3:0] strobes,input [1:0] width,
             input bit instruction,input bit fault,output [31:0] result);
  integer count,acks,j;
  begin
   @(negedge clk); addr=address; wdata=data; wstrb=strobes; size=width; fetch=instruction; valid=1;
   count=0; acks=0;
   begin : wait_ready
    forever begin
     @(posedge clk);
     if(ready) begin
      acks=acks+1; result=rdata;
      if(error!==fault) $fatal(1,"bus fault mismatch at %h",address);
      disable wait_ready;
     end
     count=count+1; if(count>10) $fatal(1,"memory timeout");
    end
   end
   for(j=0;j<3;j=j+1) begin @(posedge clk); if(ready) acks=acks+1; end
   if(acks!=1) $fatal(1,"duplicate bus effect");
   @(negedge clk); valid=0;
   repeat(2) @(negedge clk);
   checks=checks+1;
  end
 endtask
 task read_expect(input [31:0] address,expected);
  begin access(address,0,0,2,0,0,value); if(value!==expected) $fatal(1,"memory data %h got %h expected %h",address,value,expected); end
 endtask
 initial begin
  repeat(4) @(negedge clk); rst=0;
  // Both RAM boundaries and every byte lane, including lane 3 signed data.
  access('h10000,'h12345678,15,2,0,0,value); read_expect('h10000,'h12345678);
  access('h11ffc,'h89abcdef,15,2,0,0,value); read_expect('h11ffc,'h89abcdef);
  for(i=0;i<4;i=i+1) access('h10000+i,32'hff<<(i*8),1<<i,0,0,0,value);
  read_expect('h10000,32'hffffffff);
  access('h10000,'h00008001,3,1,0,0,value);
  access('h10002,'h7fff0000,12,1,0,0,value);
  read_expect('h10000,'h7fff8001);
  access('h10000,0,15,2,1,1,value); read_expect('h10000,'h7fff8001);
  access(0,0,0,2,1,0,value); if(value==0 || ^value===1'bx) $fatal(1,"ROM initialization");
  access(0,0,15,2,0,1,value); access('h2000,0,0,2,0,1,value);
  access('h12000,0,0,2,0,1,value); access('h80000000,0,0,2,0,1,value);
  access('h10003000,1,15,2,0,0,value); read_expect('h10003000,1);
  access('h10003004,'he0,15,2,0,0,value); read_expect('h10003004,'he0);
  access('h10003008,0,15,2,0,1,value);
  access('h10003000,0,0,2,1,1,value);
  access('h10003000,0,0,0,0,1,value);
  access('h10003001,0,15,2,0,1,value);
  access('h10003000,0,1,2,0,1,value); read_expect('h10003000,1);
  access('h10010000,'hab,15,2,0,0,value);
  access('h100112bc,'hcd,15,2,0,0,value);
  if(dut.video.tiles[0]!==8'hab || dut.video.tiles[1199]!==8'hcd) $fatal(1,"tile addressing");
  access('h100112c0,0,15,2,0,1,value); access('h10010000,0,0,2,0,1,value);
  read_expect('h10002004,0); access('h10002004,0,0,2,1,1,value);
  access('h10004000,'hcafebabe,15,2,0,0,value); read_expect('h10004000,'hcafebabe);
  read_expect('h10004008,0); read_expect('h1000401c,'hd1060001);
  access('h1000401c,0,15,2,0,1,value);
  for(i=8;i<=24;i=i+4) begin
   access('h10004000+i,i,15,2,0,0,value);
   read_expect('h10004000+i,i);
   access('h10004000+i,0,1,2,0,1,value);
   read_expect('h10004000+i,i);
  end
  access('h10004020,0,0,2,0,1,value);
  $display("PASS memory/MMIO: %0d transactions, lane masks, boundaries, decode faults, no duplicate effects",checks); $finish;
 end
 initial begin #1000000; $fatal(1,"bus timeout"); end
endmodule
