`timescale 1ns/1ps
// Independent command-level BL1/CL2 model, full capacity, timing assertions.
// Not a vendor electrical model. 6 ns output delay, 1 ns hold after next edge.
module sdram_model(input clk,reset,cke,cs_n,ras_n,cas_n,we_n,
 input [11:0] a,input [1:0] ba,dqm,inout [15:0] dq);
 reg [15:0] mem[0:4194303];
 reg [11:0] row[0:3]; reg [3:0] active=0;
 integer tick=0,last_pre[0:3],last_act[0:3],last_write[0:3];
 integer last_refresh=-100,refreshes=0,precharges=0,mode=0;
 integer pending=-1,idx,b,last_mode=-100,power_cycles=0;
 reg [15:0] q; reg oe=0; reg [1:0] mask1=0,mask2=0;
 assign dq=oe?q:16'bz;
 initial for(b=0;b<4;b=b+1) begin last_pre[b]=-100;last_act[b]=-100;last_write[b]=-100;end
 always @(posedge clk) begin
  tick=tick+1;
  if(reset) begin active=0;pending=-1;oe<=0;mode=0;refreshes=0;precharges=0;power_cycles=0;last_mode=-100; last_refresh=tick-100; end
  else begin
   power_cycles=power_cycles+1;
   if(oe) oe<=#1 0;
   if(pending>=0) begin
    if(pending==0) begin q<=#6 mem[idx];oe<=#6 1;pending=-1;end
    else pending=pending-1;
   end
   mask2=mask1;mask1=dqm;
   if(cke && !cs_n) begin
    if(tick-last_mode<2 && {ras_n,cas_n,we_n}!=7)$fatal(1,"mode recovery");
    if(tick-last_refresh<4 && {ras_n,cas_n,we_n}!=7) $fatal(1,"tRFC");
    case({ras_n,cas_n,we_n})
     3'b010: begin
      if(precharges==0 && power_cycles<10000)$fatal(1,"200us power-up wait");
      precharges=precharges+1;
      for(b=0;b<4;b=b+1) if(a[10] || b==ba) begin
       if(active[b] && (tick-last_act[b]<3 || tick-last_write[b]<2)) $fatal(1,"tRAS/tWR");
       active[b]=0;last_pre[b]=tick;
      end
     end
     3'b001: begin
      if(active!=0) $fatal(1,"refresh active bank");
      for(b=0;b<4;b=b+1) if(tick-last_pre[b]<2) $fatal(1,"refresh tRP");
      last_refresh=tick;refreshes=refreshes+1;
     end
     3'b000: begin
      if(active!=0 || refreshes<8 || precharges<1 || a!=12'h020) $fatal(1,"initialization/mode");
      mode=1;last_mode=tick;
     end
     3'b011: begin
      if(!mode || active[ba] || tick-last_pre[ba]<2) $fatal(1,"ACT state/tRP");
      active[ba]=1;row[ba]=a;last_act[ba]=tick;
     end
     3'b100,3'b101: begin
      if(!active[ba] || tick-last_act[ba]<2 || a[10]) $fatal(1,"column state/tRCD");
      if(we_n) begin idx={ba,row[ba],a[7:0]};pending=1; end
      else begin
       if(!dqm[0]) mem[{ba,row[ba],a[7:0]}][7:0]=dq[7:0];
       if(!dqm[1]) mem[{ba,row[ba],a[7:0]}][15:8]=dq[15:8];
       last_write[ba]=tick;
       if((!dqm[0] && (^dq[7:0]===1'bx)) || (!dqm[1] && (^dq[15:8]===1'bx))) $fatal(1,"write bus X/Z");
      end
     end
    endcase
   end
  end
 end
endmodule
