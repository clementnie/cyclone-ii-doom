`timescale 1ns/1ps
module phase10_bus #(parameter ROM_FILE="firmware/boot.hex")(
 input wire [479:0] jtag_source,output wire [31:0] perf_underflows,output wire [95:0] jtag_probe,output wire [31:0] perf_command,perf_selector,
 input wire cpu_halted, input wire [3:0] cpu_cause,
 input wire clk,rst,valid,fetch, input wire [31:0] addr,wdata,
 input wire [3:0] wstrb, input wire [1:0] size,
 output wire ready,error, output reg [31:0] rdata,
 input wire ext_ready,ext_error, input wire [31:0] ext_data, output wire ext_valid,
 input wire ps2_clk,ps2_data,
 output wire dma_valid,output wire [31:0] dma_addr,input wire dma_ready,dma_error,input wire [31:0] dma_data,
 input wire [31:0] video_words,cpu_words,max_video_wait,
 output wire pixel_clk,hs,vs,blank, output wire [9:0] red,green,blue,
 output wire [31:0] frames, output reg [31:0] mailbox
);
 wire jtag_hit=addr[31:12]==20'h10007;
 wire jtag_ready,jtag_error;wire [31:0] jtag_data;
 phase10_mailbox loader_io(.clk(clk),.rst(rst),.source(jtag_source),.probe(jtag_probe),.command(perf_command),.selector(perf_selector),
 .valid(valid&&jtag_hit),.fetch(fetch),.addr(addr),.wdata(wdata),.wstrb(wstrb),.size(size),
 .ready(jtag_ready),.error(jtag_error),.rdata(jtag_data));
 
 wire ext_hit=addr>=32'h20000000 && addr<32'h20800000;
 assign ext_valid=valid && ext_hit;
 wire mem_hit=addr<32'h2000 || (addr>=32'h10000 && addr<32'h12000);
 wire key_hit=addr[31:12]==20'h10002;
 wire video_hit=addr[31:12]==20'h10003;
 wire sys_hit=addr[31:12]==20'h10004;
 wire fb_hit=addr[31:12]==20'h10006;
 wire tile_hit=addr>=32'h10010000 && addr<32'h100112c0; // 1200 x 4-byte cells
 wire io_ok=!fetch && size==2 && addr[1:0]==0 && (wstrb==0 || wstrb==15);
 reg served;
 wire io_accept=valid && !rst && !mem_hit && !ext_hit && !served;
 wire mem_ready,mem_error,key_ready,key_error;
 wire [31:0] mem_data,key_data;
 reg io_error;
 reg [1:0] mode;
 reg [7:0] color;
 reg [31:0] cycles;
 reg [31:0] ram_result,key_status,last_key,key_events,diag_error;
 wire tile_we=io_accept && io_ok && tile_hit && wstrb==15;
 assign ready=valid && !rst && (jtag_hit?jtag_ready:ext_hit?ext_ready:mem_hit?mem_ready:((key_hit && io_ok)?key_ready:!served));
 assign error=jtag_hit?jtag_error:ext_hit?ext_error:mem_hit?mem_error:((key_hit && io_ok)?key_error:io_error);
 onchip_memory #(.ROM_FILE(ROM_FILE)) memory(
  .clk(clk),.rst(rst),.valid(valid && mem_hit),.fetch(fetch),.addr(addr),.wdata(wdata),
  .wstrb(wstrb),.ready(mem_ready),.error(mem_error),.rdata(mem_data));
 ps2_keyboard_mmio #(.CLK_HZ(50000000)) keyboard(
  .clk(clk),.rst(rst),.ps2_clk(ps2_clk),.ps2_data(ps2_data),
  .bus_valid(valid && key_hit && io_ok),.bus_addr(addr[11:0]),
  .bus_wdata(wdata),.bus_wstrb(wstrb),.bus_ready(key_ready),.bus_error(key_error),.bus_rdata(key_data));
 wire old_pixel,old_hs,old_vs,old_blank,fb_pixel,fb_hs,fb_vs,fb_blank;
 wire [9:0] old_red,old_green,old_blue;
 wire [31:0] old_frames,fb_frames,underflows;
 assign perf_underflows=underflows;
 wire [11:0] fb_rgb;
 wire [9:0] fb_scan_y;
 reg fb_enable,fb_slot;reg [1:0] fb_resolution;
 wire fb_active,fb_active_slot,fb_pending;
 wire pal_we=io_accept && io_ok && fb_hit && addr[11:10]==2'b01 && wstrb==15;
 framebuffer pixels(.resolution_request(fb_resolution),.clk(clk),.rst(rst),.enable_request(fb_enable),.slot_request(fb_slot),
 .pal_we(pal_we),.pal_addr(addr[9:2]),.pal_data(wdata[11:0]),
 .dma_valid(dma_valid),.dma_addr(dma_addr),.dma_ready(dma_ready),.dma_error(dma_error),.dma_data(dma_data),
 .active(fb_active),.active_slot(fb_active_slot),.pending(fb_pending),.underflows(underflows),.frames(fb_frames),
 .pixel_clk(fb_pixel),.hs(fb_hs),.vs(fb_vs),.blank(fb_blank),.rgb(fb_rgb),.scan_x(),.scan_y(fb_scan_y));
 assign pixel_clk=fb_active?fb_pixel:old_pixel;
 assign hs=fb_active?fb_hs:old_hs;assign vs=fb_active?fb_vs:old_vs;assign blank=fb_active?fb_blank:old_blank;
 assign red=fb_active?{fb_rgb[11:8],fb_rgb[11:8],fb_rgb[11:10]}:old_red;
 assign green=fb_active?{fb_rgb[7:4],fb_rgb[7:4],fb_rgb[7:6]}:old_green;
 assign blue=fb_active?{fb_rgb[3:0],fb_rgb[3:0],fb_rgb[3:2]}:old_blue;
 assign frames=fb_frames;
 vga_tiles video(.heartbeat(mailbox),.ram_result(ram_result),
  .key_status(key_status),.last_key(last_key),.key_events(key_events),
  .diag_error(diag_error),.cpu_halted(cpu_halted),.cpu_cause(cpu_cause),.clk(clk),.rst(rst),.mode(mode),.color(color),
  .tile_we(tile_we),.tile_addr(addr[12:2]),.tile_data(wdata[7:0]),
  .pixel_clk(old_pixel),.hs(old_hs),.vs(old_vs),.blank(old_blank),
  .red(old_red),.green(old_green),.blue(old_blue),.frames(old_frames),.scan_x(),.scan_y());
 always @* begin
  rdata=0; io_error=!io_ok;
  if(jtag_hit) rdata=jtag_data;
  else if(ext_hit) rdata=ext_data;
  else if(mem_hit) rdata=mem_data;
  else if(key_hit) rdata=key_data;
  else if(video_hit) begin
   case(addr[11:0])
    0: rdata={30'b0,mode};
    4: rdata={24'b0,color};
    8: begin rdata=frames; if(|wstrb) io_error=1; end
    default: io_error=1;
   endcase
  end else if(sys_hit) begin
   case(addr[11:0])
    0: rdata=mailbox;
    4: begin rdata=cycles; if(|wstrb) io_error=1; end
    8: rdata=ram_result;
    12: rdata=key_status;
    16: rdata=last_key;
    20: rdata=key_events;
    24: rdata=diag_error;
    28: begin rdata=32'hD4B00001; if(|wstrb) io_error=1; end
    default: io_error=1;
   endcase
  end else if(fb_hit) begin
   case(addr[11:0])
    0:rdata={31'b0,fb_enable};4:rdata={31'b0,fb_slot};
    8:begin rdata={29'b0,fb_pending,fb_active_slot,fb_active};if(|wstrb)io_error=1;end
    12:begin rdata=underflows;if(|wstrb)io_error=1;end
    16:begin rdata=video_words;if(|wstrb)io_error=1;end
    20:begin rdata=cpu_words;if(|wstrb)io_error=1;end
    24:begin rdata=max_video_wait;if(|wstrb)io_error=1;end
    28:begin rdata=fb_frames;if(|wstrb)io_error=1;end
    32:begin rdata={22'b0,fb_scan_y};if(|wstrb)io_error=1;end
    36:rdata={30'b0,fb_resolution};
    default:if(addr[11:10]!=2'b01 || wstrb!=15)io_error=1;
   endcase
  end else if(tile_hit) begin if(wstrb!=15) io_error=1; end
  else io_error=1;
 end
 always @(posedge clk) begin
  if(rst) begin fb_enable<=0;fb_slot<=0;fb_resolution<=0;served<=0; mode<=3; color<=0; mailbox<=0; cycles<=0;
   ram_result<=0; key_status<=0; last_key<=0; key_events<=0; diag_error<=0; end
  else begin
   cycles<=cycles+1'b1;
   if(!valid) served<=0;
   else if(ready) served<=1;
   if(io_accept && !io_error && wstrb==15) begin
    if(fb_hit && addr[11:0]==0)fb_enable<=wdata[0];
    if(fb_hit && addr[11:0]==4)fb_slot<=wdata[0];
    if(fb_hit && addr[11:0]==36)fb_resolution<=wdata[1:0];
    if(video_hit && addr[11:0]==0) mode<=wdata[1:0];
    if(video_hit && addr[11:0]==4) color<=wdata[7:0];
    if(sys_hit) case(addr[11:0])
     0: mailbox<=wdata;
     8: ram_result<=wdata;
     12: key_status<=wdata;
     16: last_key<=wdata;
     20: key_events<=wdata;
     24: diag_error<=wdata;
    endcase
   end
  end
 end
endmodule
