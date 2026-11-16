`timescale 1ns/1ps
module tb_cache;
 reg clk=0;always #10 clk=~clk;
 reg rst=1,c_valid=0,c_fetch=0;reg [31:0] c_addr=0,c_wdata=0;reg [3:0] c_wstrb=0;reg [1:0] c_size=2;
 wire c_ready,c_error,m_valid,m_fetch;wire [31:0] c_rdata,m_addr,m_wdata;wire [3:0] m_wstrb;wire [1:0] m_size;reg m_ready=0,m_error=0;reg [31:0] m_rdata=0;wire hit_event,miss_event;
 instruction_cache dut(.*);
 integer delay_count=0,requests=0;reg served=0;reg [31:0] stored=32'h12345678;reg inject=0;
 always @(posedge clk)begin
  m_ready<=0;
  if(!m_valid)begin served<=0;delay_count<=0;end
  else if(!served)begin
   if(delay_count==6)begin
    served<=1;m_ready<=1;m_error<=inject;m_rdata<=m_addr==32'h20020000 ? stored : m_addr^32'haabbccdd;requests<=requests+1;
    if(|m_wstrb&&(m_addr&32'hfffffffc)==32'h20020000)
     for(integer k=0;k<4;k=k+1)if(m_wstrb[k])stored[k*8+:8]<=m_wdata[k*8+:8];
   end else delay_count<=delay_count+1;
  end
 end
 task access(input [31:0] a,d,input f,input [3:0] wr,input [31:0] expected,input err,input integer transfers);
 integer before_count,n;
 begin
  @(negedge clk);before_count=requests;c_addr=a;c_fetch=f;c_wdata=d;c_wstrb=wr;c_valid=1;n=0;
  while(!c_ready)begin @(negedge clk);n=n+1;if(n>100)$fatal(1,"timeout");end
  if(c_error!==err||(!err&&!wr&&c_rdata!==expected))$fatal(1,"response %h got %h err %b",a,c_rdata,c_error);
  @(negedge clk);c_valid=0;repeat(4)@(negedge clk);
  if(requests-before_count!=transfers)$fatal(1,"transfer count %d wanted %d",requests-before_count,transfers);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  access('h20020000,0,1,0,'h12345678,0,1);access('h20020000,0,1,0,'h12345678,0,0);
  access('h20021000,0,1,0,32'h20021000^32'haabbccdd,0,1); // direct-map conflict
  access('h20020000,0,1,0,'h12345678,0,1);
  access('h20020000,'hdeadbeef,0,15,0,0,1); // coherent code store
  access('h20020000,0,1,0,'hdeadbeef,0,1);access('h20020000,0,1,0,'hdeadbeef,0,0);
  access('h10004004,0,0,0,32'h10004004^32'haabbccdd,0,1); // MMIO never cached
  access('h10004004,0,0,0,32'h10004004^32'haabbccdd,0,1);
  access('h20020000,0,0,0,'hdeadbeef,0,1); // data never cached
  @(negedge clk);rst=1;@(negedge clk);rst=0;
  access('h20020000,0,1,0,'hdeadbeef,0,1);
  inject=1;access('h20022000,0,1,0,0,1,1);inject=0;
  access('h20022000,0,1,0,32'h20022000^32'haabbccdd,0,1);
  c_size=0;access('h20020000,'h000000aa,0,1,0,0,1);c_size=2;
  access('h20020000,0,1,0,'hdeadbeaa,0,1);
  c_size=1;access('h20020002,'h12340000,0,12,0,0,1);c_size=2;
  access('h20020000,0,1,0,'h1234beaa,0,1);
  @(negedge clk);c_valid=1;c_fetch=1;c_addr=32'h20023000;
  wait(m_valid);@(negedge clk);rst=1;c_valid=0;repeat(3)@(negedge clk);rst=0;
  access('h20023000,0,1,0,32'h20023000^32'haabbccdd,0,1);
  $display("PASS cache: hits/misses, conflicts, coherent stores, reset, data/MMIO bypass, errors not cached, backpressure");$finish;
 end
 initial begin #100000;$fatal(1,"watchdog");end
endmodule
