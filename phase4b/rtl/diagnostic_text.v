`timescale 1ns/1ps
// 40 columns x 30 rows; every 8x8 glyph is doubled to 16x16 pixels.
// Values are captured in vertical blank, so a photograph has coherent fields.
module diagnostic_text(
 input wire clk,rst,phase, input wire [9:0] x,y,
 input wire [31:0] frames,heartbeat,ram_result,key_status,last_key,key_events,diag_error,
 input wire cpu_halted, input wire [3:0] cpu_cause,
 output reg [7:0] rgb
);
 reg [31:0] hb,fc,ram,ks,key,events,code,previous_hb;
 reg [6:0] stale_frames;
 reg [5:0] marker;
 wire [5:0] col=x[9:4];
 wire [4:0] row=y[8:4];
 reg [7:0] ch;
 reg [319:0] line_text;
 reg [31:0] number;
 reg numeric;
 reg [3:0] digit;
 wire [7:0] glyph;
 // ROM address is stable on the phase=0 edge, one 50 MHz clock before
 // phase=1 launches RGB/sync. The font output and x bit index refer to the
 // SAME pixel, including the first/last doubled column and line rollover.
 diagnostic_font font(.clk(clk),.address({ch[5:0]^6'h20,y[3:1]}),.pixels(glyph));
 always @(posedge clk) begin
  if(rst) begin
   hb<=0; fc<=0; ram<=0; ks<=0; key<=0; events<=0; code<=0;
   previous_hb<=0; stale_frames<=0; marker<=0;
  end else if(phase && x==0 && y==480) begin
   hb<=heartbeat; fc<=frames; ram<=ram_result;
   ks<=key_status; key<=last_key; events<=key_events;
   previous_hb<=heartbeat;
   if(heartbeat!=previous_hb) stale_frames<=0;
   else if(stale_frames<60) stale_frames<=stale_frames+1'b1;
   if(marker==36) marker<=0; else marker<=marker+1'b1;
   // Hardware trap/watchdog diagnoses continue even if firmware stops.
   if(cpu_halted) code<=32'he1000000 | {28'b0,cpu_cause};
   else if(stale_frames>=60) code<=32'he005;
   else code<=diag_error;
  end
 end
 always @* begin
  line_text="                                        ";
  number=0; numeric=0; digit=0;
  case(row)
   1: line_text=" CYCLONE II DIAGNOSTICS                 ";
   3: line_text=" VIDEO D4B00001   EP2C20 / RV32I        ";
   5: begin line_text=" CPU HEARTBEAT:          CPU            "; number=hb; numeric=1; end
   7: begin line_text=" VGA FRAMES:             HW             "; number=fc; numeric=1; end
   9: begin
    if(ks[10]) line_text=" PS/2 CPU: RX ERROR                     ";
    else if(ks[9]) line_text=" PS/2 CPU: FIFO OVERFLOW                ";
    else if(events!=0) line_text=" PS/2 CPU: EVENTS SEEN                  ";
    else line_text=" PS/2 CPU: WAIT FOR KEY                 ";
   end
   11: begin line_text=" DMA WORDS:                CPU          "; number=key; numeric=1; end
   13: begin line_text=" ERROR COUNT:             CPU           "; number=events; numeric=1; end
   15: begin
    case(ram)
     1: line_text=" VIDEO: FRAMEBUFFER READY               ";
     2: line_text=" VIDEO: SEE ERROR COUNTER               ";
     default: line_text=" VIDEO: DIAGNOSTIC MODE                 ";
    endcase
   end
   17: begin line_text=" ERROR CODE:             0=NO ERROR     "; number=code; numeric=1; end
   19: line_text=" HEX VALUES / KEY ID + 100 WHEN DOWN    ";
   21: line_text=" RED         GREEN        BLUE          ";
   27: line_text=" REFRESH MARKER - HW                    ";
   29: line_text=" ESC: PIXELS / DIAGNOSTICS              ";
   default: line_text="                                        ";
  endcase
  ch=8'h20;
  if(col<40) ch=(line_text >> ((39-col)*8));
  // Fixed numeric columns 16..23, big-endian hexadecimal presentation.
  if(numeric && col>=16 && col<24) begin
   digit=number >> ((23-col)*4);
   ch=(digit<10)?(8'h30+{4'b0,digit}):(8'h41+{4'b0,digit}-8'd10);
  end
  rgb=0;
  if(x<640 && y<480) begin
   if(glyph[7-x[3:1]]) rgb=8'hff;
   if(y>=352 && y<416) begin
    if(x>=16 && x<192) rgb=8'he0;
    else if(x>=224 && x<400) rgb=8'h1c;
    else if(x>=432 && x<608) rgb=8'h03;
   end
   if(y>=456 && y<464 && x>=16 && x<608) begin
    rgb=8'h00;
    if(x[9:4]==marker+1'b1) rgb=8'hff;
   end
  end
 end
endmodule
