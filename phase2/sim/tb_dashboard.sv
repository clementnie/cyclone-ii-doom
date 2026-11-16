`timescale 1ns/1ps
module tb_dashboard;
 reg clk=0; always #10 clk=~clk;
 reg rst=1;
 reg [1:0] mode=3; reg [7:0] color=0;
 reg tile_we=0; reg [10:0] tile_addr=0; reg [7:0] tile_data=0;
 reg [31:0] heartbeat=32'h1234abcd,ram_result=1,key_status=0,last_key=32'h105,key_events=32'h89abcdef,diag_error=0;
 reg cpu_halted=0; reg [3:0] cpu_cause=0;
 wire pixel_clk,hs,vs,blank;
 wire [9:0] red,green,blue,scan_x,scan_y;
 wire [31:0] frames;
 vga_tiles dut(.*);
 function [34:0] bitmap(input [7:0] c);
  begin case(c)
   8'd32: bitmap=35'b00000000000000000000000000000000000;
   8'd65: bitmap=35'b01110100011000111111100011000110001;
   8'd66: bitmap=35'b11110100011000111110100011000111110;
   8'd67: bitmap=35'b01111100001000010000100001000001111;
   8'd68: bitmap=35'b11110100011000110001100011000111110;
   8'd69: bitmap=35'b11111100001000011110100001000011111;
   8'd70: bitmap=35'b11111100001000011110100001000010000;
   8'd71: bitmap=35'b01111100001000010111100011000101111;
   8'd72: bitmap=35'b10001100011000111111100011000110001;
   8'd73: bitmap=35'b11111001000010000100001000010011111;
   8'd74: bitmap=35'b00111000100001000010100101001001100;
   8'd75: bitmap=35'b10001100101010011000101001001010001;
   8'd76: bitmap=35'b10000100001000010000100001000011111;
   8'd77: bitmap=35'b10001110111010110101100011000110001;
   8'd78: bitmap=35'b10001110011010110011100011000110001;
   8'd79: bitmap=35'b01110100011000110001100011000101110;
   8'd80: bitmap=35'b11110100011000111110100001000010000;
   8'd81: bitmap=35'b01110100011000110001101011001001101;
   8'd82: bitmap=35'b11110100011000111110101001001010001;
   8'd83: bitmap=35'b01111100001000001110000010000111110;
   8'd84: bitmap=35'b11111001000010000100001000010000100;
   8'd85: bitmap=35'b10001100011000110001100011000101110;
   8'd86: bitmap=35'b10001100011000110001100010101000100;
   8'd87: bitmap=35'b10001100011000110101101011010101010;
   8'd88: bitmap=35'b10001100010101000100010101000110001;
   8'd89: bitmap=35'b10001100010101000100001000010000100;
   8'd90: bitmap=35'b11111000010001000100010001000011111;
   8'd48: bitmap=35'b01110100011001110101110011000101110;
   8'd49: bitmap=35'b00100011000010000100001000010001110;
   8'd50: bitmap=35'b01110100010000100010001000100011111;
   8'd51: bitmap=35'b11110000010000101110000010000111110;
   8'd52: bitmap=35'b00010001100101010010111110001000010;
   8'd53: bitmap=35'b11111100001000011110000010000111110;
   8'd54: bitmap=35'b01110100001000011110100011000101110;
   8'd55: bitmap=35'b11111000010001000100010000100001000;
   8'd56: bitmap=35'b01110100011000101110100011000101110;
   8'd57: bitmap=35'b01110100011000101111000010000101110;
   8'd58: bitmap=35'b00000001000010000000001000010000000;
   8'd45: bitmap=35'b00000000000000011111000000000000000;
   8'd47: bitmap=35'b00001000100001000100010000100010000;
   8'd43: bitmap=35'b00000001000010011111001000010000000;
   8'd61: bitmap=35'b00000000001111100000111110000000000;
   default: bitmap=0;
  endcase end
 endfunction
 reg [319:0] text_line;
 reg [7:0] character,expected;
 reg [34:0] bits;
 integer f,i,x,y,c,r,fd;
 initial begin
  repeat(5) @(negedge clk); rst=0;
  fd=$fopen("build/dashboard.ppm","w");
  $fwrite(fd,"P3\n640 480\n255\n");
  for(f=0;f<3;f=f+1) begin
   if(f==1) begin ram_result=2; diag_error=32'he002; key_status=32'h400; end
   for(i=0;i<420000;i=i+1) begin
    @(negedge pixel_clk); #1;
    x=i%800; y=i/800; c=x/16; r=y/16;
    if(hs!==!(x>=656 && x<752) || vs!==!(y>=490 && y<492) || blank!==(x<640 && y<480))
     $fatal(1,"dashboard sync/blank %d,%d",x,y);
    text_line="                                        ";
    case(r)
     1: text_line=" CYCLONE II DIAGNOSTICS                 ";
     3: text_line=" BUILD D1060001   EP2C20 / RV32I        ";
     5: text_line=" CPU HEARTBEAT: 1234ABCD CPU            ";
     7: text_line=" VGA FRAMES:    00000000 HW             ";
     9: text_line=" PS/2 CPU: EVENTS SEEN                  ";
     11: text_line=" LAST EVENT:    00000105 CPU            ";
     13: text_line=" KEY EVENTS:    89ABCDEF CPU            ";
     15: text_line=" RAM CPU: PASS - 4 KIB SCRATCH          ";
     17: text_line=" ERROR CODE:    00000000 0=NO ERROR     ";
     19: text_line=" HEX VALUES / KEY ID + 100 WHEN DOWN    ";
     21: text_line=" RED         GREEN        BLUE          ";
     27: text_line=" REFRESH MARKER - HW                    ";
     29: text_line=" KEYS: ARROWS CTRL SPACE ESC            ";
    endcase
    if(f==0) begin
     case(r)
      5: text_line=" CPU HEARTBEAT: 00000000 CPU            ";
      9: text_line=" PS/2 CPU: WAIT FOR KEY                 ";
      11: text_line=" LAST EVENT:    00000000 CPU            ";
      13: text_line=" KEY EVENTS:    00000000 CPU            ";
      15: text_line=" RAM CPU: NOT TESTED                    ";
     endcase
    end
    if(f==2) begin
     case(r)
      7: text_line=" VGA FRAMES:    00000001 HW             ";
      9: text_line=" PS/2 CPU: RX ERROR                     ";
      15: text_line=" RAM CPU: FAIL - 4 KIB SCRATCH          ";
      17: text_line=" ERROR CODE:    0000E002 0=NO ERROR     ";
     endcase
    end
    expected=0;
    if(x<640 && y<480) begin
     character=(text_line >> ((39-c)*8));
     bits=bitmap(character);
     if((y%16)/2<7 && (x%16)/2>=1 && (x%16)/2<=5)
      if(bits[34-((y%16)/2)*5-((x%16)/2-1)]) expected=8'hff;
     if(y>=352 && y<416) begin
      if(x>=16 && x<192) expected=8'he0;
      else if(x>=224 && x<400) expected=8'h1c;
      else if(x>=432 && x<608) expected=8'h03;
     end
     if(y>=456 && y<464 && x>=16 && x<608) begin
      if(f==2) begin
     case(r)
      7: text_line=" VGA FRAMES:    00000001 HW             ";
      9: text_line=" PS/2 CPU: RX ERROR                     ";
      15: text_line=" RAM CPU: FAIL - 4 KIB SCRATCH          ";
      17: text_line=" ERROR CODE:    0000E002 0=NO ERROR     ";
     endcase
    end
    expected=0;
      if(c==f+1) expected=8'hff;
     end
    end
    if(red!=={expected[7:5],expected[7:5],expected[7:5],expected[7]} ||
       green!=={expected[4:2],expected[4:2],expected[4:2],expected[4]} ||
       blue!=={expected[1:0],expected[1:0],expected[1:0],expected[1:0],expected[1:0]})
      $fatal(1,"dashboard pixel frame=%d x=%d y=%d char=%h got=%h,%h,%h expected=%h",f,x,y,character,red,green,blue,expected);
    if(f==1 && x<640 && y<480)
     $fwrite(fd,"%0d %0d %0d\n",red*255/1023,green*255/1023,blue*255/1023);
   end
  end
  $fclose(fd);
  // Accelerate only the blanking capture coordinates to test 60-frame stall
  // watchdog, saturation, error priority and recovery without a 1s simulation.
  diag_error=0;
  force dut.x=0; force dut.y=480;
  repeat(65) @(negedge pixel_clk);
  #1; if(dut.dashboard.code!==32'he005) $fatal(1,"heartbeat watchdog");
  heartbeat=heartbeat+1;
  repeat(3) @(negedge pixel_clk);
  #1; if(dut.dashboard.code!==0) $fatal(1,"heartbeat watchdog recovery");
  cpu_halted=1; cpu_cause=4'd2;
  repeat(2) @(negedge pixel_clk);
  #1; if(dut.dashboard.code!==32'he1000002) $fatal(1,"trap code");
  $display("PASS dashboard: 1260000 golden pixels, glyph/cell/line alignment, sync/blank, RGB blocks, coherent hex, NOT TESTED/PASS/FAIL, marker, watchdog and trap");
  $finish;
 end
 initial begin #60000000; $fatal(1,"dashboard timeout"); end
endmodule
