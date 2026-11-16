`timescale 1ns/1ps
module tb_video_modes;
 reg clk=0;always #10 clk=~clk;
 reg rst=1,enable_request=0,slot_request=0,pal_we=0;
 reg [1:0] resolution_request=0;reg [7:0] pal_addr;reg [11:0] pal_data;
 wire dma_valid,dma_ready,dma_error,active,active_slot,pending,pixel_clk,hs,vs,blank;
 wire [31:0] dma_addr,dma_data,underflows,frames;wire [11:0] rgb;wire [9:0] scan_x,scan_y;
 framebuffer dut(.*);
 reg served=0;reg [5:0] delay_count=0;
 assign dma_ready=dma_valid&&!served&&delay_count==30;
 assign dma_error=0;
 function [7:0] p(input integer a);p=((a%320)^((a/320)*13))&255;endfunction
 wire [31:0] offset=dma_addr-(active_slot?32'h20010000:32'h20000000);
 // Byte pattern follows the packed row stride for each mode.
 assign dma_data={p(offset+3),p(offset+2),p(offset+1),p(offset)};
 always @(posedge clk)if(rst||!dma_valid)begin served<=0;delay_count<=0;end
 else if(dma_ready)served<=1;else if(!served)delay_count<=delay_count+1'b1;
 integer m,i,x,y,sx,sy,stride,off,count;reg [11:0] want;reg sample;
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(i=0;i<256;i++)begin @(negedge clk);pal_we=1;pal_addr=i;pal_data={4'(i>>4),4'(i&15),4'((i>>4)^(i&15))};end
  @(negedge clk);pal_we=0;
  for(m=0;m<4;m++)begin
   @(negedge clk);resolution_request=m;slot_request=m&1;enable_request=1;
   wait(dut.resolution==m&&active&&active_slot==(m&1));
   wait(dut.x==0&&dut.y==0);count=0;
   while(count<420000)begin
    @(posedge clk);sample=dut.ce2;#1;
    if(sample)begin
     x=scan_x;y=scan_y;want=0;
     if(x<640&&y>=40&&y<440)begin
      sx=m==0?x/2:x/4;sy=m==1?(y-40)/4:m==2?((y-40)*3)/10:(y-40)/2;
      stride=m==0?320:160;off=p(sy*stride+sx);want={4'(off>>4),4'(off&15),4'((off>>4)^(off&15))};
     end
     if(rgb!==want)$fatal(1,"mode %d pixel %d,%d got %h want %h uf %d",m,x,y,rgb,want,underflows);
     count++;
    end
   end
   if(underflows)$fatal(1,"underflow mode %d",m);
   $display("PASS VGA mode %d, 420000 pixel periods, packed stride and 31-cycle DMA backpressure",m);
  end
  $finish;
 end
 initial begin #250000000;$fatal(1,"watchdog");end
endmodule
