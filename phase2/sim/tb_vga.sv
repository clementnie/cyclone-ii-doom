`timescale 1ns/1ps
module tb_vga;
 reg clk=0; always #10 clk=~clk;
 reg rst=1;
 reg [1:0] mode=0; reg [7:0] color=8'he3;
 reg tile_we=0; reg [10:0] tile_addr; reg [7:0] tile_data;
 wire pixel_clk,hs,vs,blank;
 wire [9:0] red,green,blue,scan_x,scan_y;
 wire [31:0] frames;
 reg [31:0] heartbeat=32'h12345678,ram_result=0,key_status=0,last_key=0,key_events=0,diag_error=0;
 reg cpu_halted=0; reg [3:0] cpu_cause=0;
 vga_tiles dut(.*);
 integer i,f,x,y,active_count,hs_count,vs_count;
 reg [7:0] expected;
 time last_fall=0;
 always @(posedge pixel_clk) if(!rst && last_fall!=0)
  if($time-last_fall!=20) $fatal(1,"DAC setup interval must be 20 ns");
 initial begin
  for(i=0;i<1200;i=i+1) begin
   @(negedge clk); tile_we=1; tile_addr=i; tile_data=i;
  end
  @(negedge clk); tile_we=0; rst=0;
  for(f=0;f<3;f=f+1) begin
   mode=f; active_count=0; hs_count=0; vs_count=0;
   for(i=0;i<420000;i=i+1) begin
    @(negedge pixel_clk);
    if(last_fall!=0 && $time-last_fall!=40) $fatal(1,"pixel period");
    last_fall=$time; #1;
    x=i%800; y=i/800;
    if(hs!==!(x>=656 && x<752) || vs!==!(y>=490 && y<492)) $fatal(1,"sync mismatch %0d,%0d",x,y);
    if(blank!==(x<640 && y<480)) $fatal(1,"blanking mismatch");
    if(!hs) hs_count=hs_count+1;
    if(!vs) vs_count=vs_count+1;
    expected=0;
    if(blank) begin
     active_count=active_count+1;
     case(f)
      0: expected={x[7:5],y[7:5],x[9:8]};
      1: expected=color;
      2: expected=(y/16)*40+x/16;
     endcase
    end
    if(red!=={expected[7:5],expected[7:5],expected[7:5],expected[7]} ||
       green!=={expected[4:2],expected[4:2],expected[4:2],expected[4]} ||
       blue!=={expected[1:0],expected[1:0],expected[1:0],expected[1:0],expected[1:0]})
      $fatal(1,"RGB mismatch frame %0d pixel %0d,%0d got %h,%h,%h expected %h",f,x,y,red,green,blue,expected);
   end
   if(active_count!=307200 || hs_count!=50400 || vs_count!=1600 || frames!=f+1) $fatal(1,"frame totals");
  end
  $display("PASS VGA: 3 complete frames, 1260000 pixel checks, pattern/solid/tiles and 25 MHz clock"); $finish;
 end
 initial begin #60000000; $fatal(1,"VGA timeout"); end
endmodule
