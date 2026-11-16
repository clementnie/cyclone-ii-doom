`timescale 1ns/1ps
module tb_arbiter;
 reg clk=0;always #10 clk=~clk;reg rst=1;
 reg cv=0,vv=0;reg [31:0] ca=32'h20030000,va=32'h20000000;wire cr,vr,ce,ve,mv,mf;wire [31:0] cd,vd,ma,mw;wire [3:0] ms;wire [1:0] mz;
 reg mr=0;reg [31:0] md=0;wire [31:0] vc,cc,maxwait;
 sdram_arbiter dut(clk,rst,cv,1'b0,ca,32'h12345678,4'b0010,2'b00,cr,ce,cd,vv,va,vr,ve,vd,mv,mf,ma,mw,ms,mz,mr,1'b0,md,vc,cc,maxwait);
 integer delay_count=0,ticks=0,cwait=0,vwait=0,maxc=0,maxv=0,cbubble=0,vbubble=0;
 reg c_ack=0,v_ack=0;
 reg served=0;reg [31:0] saved_addr,saved_data;reg [3:0] saved_strobes;
 always @(posedge clk)begin
  c_ack<=cr;v_ack<=vr;ticks=ticks+1;mr<=0;
  if(!mv)served<=0;
  else if(!served)begin served<=1;delay_count<=22;saved_addr<=ma;saved_data<=mw;saved_strobes<=ms;end
  else begin
   if(ma!==saved_addr || mw!==saved_data || ms!==saved_strobes)$fatal(1,"changed in-flight request");
   if(delay_count>0 && ticks%700>7)begin delay_count<=delay_count-1;if(delay_count==1)begin md<=saved_addr^32'ha55a5aa5;mr<=1;end end
  end
  if(!rst)begin
   if(cv && !cr)cwait=cwait+1;else cwait=0;
   if(vv && !vr)vwait=vwait+1;else vwait=0;
   if(cwait>maxc)maxc=cwait;if(vwait>maxv)maxv=vwait;
   if(cwait>160 || vwait>80)$fatal(1,"starvation c=%d v=%d",cwait,vwait);
   if(cr && cd!==(ca^32'ha55a5aa5))$fatal(1,"CPU routing");
   if(vr && vd!==(va^32'ha55a5aa5))$fatal(1,"VGA routing");
  end
 end
 always @(negedge clk)if(!rst)begin
  if(c_ack)begin cv=0;cbubble=0;ca=ca+4;end else if(cbubble>0)cbubble=cbubble-1;else cv=1;
  if(v_ack)begin vv=0;vbubble=0;va=va+4;end else if(vbubble>0)vbubble=vbubble-1;else vv=1;
 end
 initial begin
  repeat(5)@(negedge clk);rst=0;
  repeat(20000)@(negedge clk);
  if(cc<100 || vc<400)$fatal(1,"grant counts");
  $display("PASS weighted arbiter: CPU grants=%d video=%d max CPU/display wait=%d/%d cycles",cc,vc,maxc,maxv);$finish;
 end
endmodule
