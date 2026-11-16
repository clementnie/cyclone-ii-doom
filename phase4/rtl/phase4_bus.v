`timescale 1ns/1ps
module phase4_bus #(parameter ROM_FILE="firmware/boot.hex")(
 input wire cpu_halted, input wire [3:0] cpu_cause,
 input wire clk,rst,valid,fetch, input wire [31:0] addr,wdata,
 input wire [3:0] wstrb, input wire [1:0] size,
 output wire ready,error, output reg [31:0] rdata,
 input wire ext_ready,ext_error, input wire [31:0] ext_data, output wire ext_valid,
 input wire ps2_clk,ps2_data,
 output wire pixel_clk,hs,vs,blank, output wire [9:0] red,green,blue,
 output wire [31:0] frames, output reg [31:0] mailbox
);
 wire ext_hit=addr>=32'h20000000 && addr<32'h20800000;
 assign ext_valid=valid && ext_hit;
 wire mem_hit=addr<32'h2000 || (addr>=32'h10000 && addr<32'h12000);
 wire key_hit=addr[31:12]==20'h10002;
 wire video_hit=addr[31:12]==20'h10003;
 wire sys_hit=addr[31:12]==20'h10004;
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
 assign ready=valid && !rst && (ext_hit?ext_ready:mem_hit?mem_ready:((key_hit && io_ok)?key_ready:!served));
 assign error=ext_hit?ext_error:mem_hit?mem_error:((key_hit && io_ok)?key_error:io_error);
 onchip_memory #(.ROM_FILE(ROM_FILE)) memory(
  .clk(clk),.rst(rst),.valid(valid && mem_hit),.fetch(fetch),.addr(addr),.wdata(wdata),
  .wstrb(wstrb),.ready(mem_ready),.error(mem_error),.rdata(mem_data));
 ps2_keyboard_mmio #(.CLK_HZ(50000000)) keyboard(
  .clk(clk),.rst(rst),.ps2_clk(ps2_clk),.ps2_data(ps2_data),
  .bus_valid(valid && key_hit && io_ok),.bus_addr(addr[11:0]),
  .bus_wdata(wdata),.bus_wstrb(wstrb),.bus_ready(key_ready),.bus_error(key_error),.bus_rdata(key_data));
 vga_tiles video(.heartbeat(mailbox),.ram_result(ram_result),
  .key_status(key_status),.last_key(last_key),.key_events(key_events),
  .diag_error(diag_error),.cpu_halted(cpu_halted),.cpu_cause(cpu_cause),.clk(clk),.rst(rst),.mode(mode),.color(color),
  .tile_we(tile_we),.tile_addr(addr[12:2]),.tile_data(wdata[7:0]),
  .pixel_clk(pixel_clk),.hs(hs),.vs(vs),.blank(blank),
  .red(red),.green(green),.blue(blue),.frames(frames),.scan_x(),.scan_y());
 always @* begin
  rdata=0; io_error=!io_ok;
  if(ext_hit) rdata=ext_data;
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
    28: begin rdata=32'hD4000001; if(|wstrb) io_error=1; end
    default: io_error=1;
   endcase
  end else if(tile_hit) begin if(wstrb!=15) io_error=1; end
  else io_error=1;
 end
 always @(posedge clk) begin
  if(rst) begin served<=0; mode<=3; color<=0; mailbox<=0; cycles<=0;
   ram_result<=0; key_status<=0; last_key<=0; key_events<=0; diag_error<=0; end
  else begin
   cycles<=cycles+1'b1;
   if(!valid) served<=0;
   else if(ready) served<=1;
   if(io_accept && !io_error && wstrb==15) begin
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
