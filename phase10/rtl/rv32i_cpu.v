`timescale 1ns/1ps
// Phase 10: decoupled fetch, registered operand read and execute pipeline.
// Single-entry instruction queue; outstanding speculative fetches are drained
// and discarded on redirects. In-order execution interlocks all dependencies.
// Unified held-valid bus with a low-valid rearm cycle, precise stopping traps.
// RV32IM: DSP multiply and radix-2 restoring divide (32 iterations).
module rv32i_cpu #(parameter RESET_PC=32'h00000000)(
 input wire clk, rst,
 output wire valid, fetch, output wire [31:0] addr, wdata,
 output wire [3:0] wstrb, output wire [1:0] size,
 input wire ready, error, input wire [31:0] rdata,
 output reg halted, output reg [3:0] cause,
 output reg [31:0] fault_pc, fault_value,
 output wire [31:0] debug_pc, output reg retired
);
 localparam FETCH=0, EXEC=1, MEMORY=2, GAP=3, STOP=4, DECODE=5, MULT=6, DIVIDE=7;
 reg [2:0] state;
 reg [31:0] pc, insn, regs[0:31];
 reg [31:0] mem_addr, mem_data, next_pc;
 reg [3:0] mem_strobes;
 reg [2:0] mem_func;
 reg [4:0] mem_rd;
 reg mem_load;
 wire [4:0] rd=insn[11:7], rs1=insn[19:15], rs2=insn[24:20];
 wire [2:0] f3=insn[14:12];
 wire [6:0] f7=insn[31:25];
 reg [31:0] a;
 reg [31:0] b;
 wire [31:0] imm_i={{20{insn[31]}},insn[31:20]};
 wire [31:0] imm_s={{20{insn[31]}},insn[31:25],insn[11:7]};
 wire [31:0] imm_b={{19{insn[31]}},insn[31],insn[7],insn[30:25],insn[11:8],1'b0};
 wire [31:0] imm_j={{11{insn[31]}},insn[31],insn[19:12],insn[20],insn[30:21],1'b0};
 reg [31:0] result, target, ea, store_data, trap_value;
 reg [3:0] strobes, trap_cause;
 reg write_rd, do_load, do_store, trap, take_branch;
 wire [31:0] shifted_read=rdata >> {mem_addr[1:0],3'b000};
 reg [31:0] load_result;
 integer i;
 // Frontend and data requests share the legacy fabric protocol.
 localparam BUS_IDLE=0, BUS_FETCH=1, BUS_DATA=2, BUS_GAP=3;
 reg [1:0] bus_state;
 reg [31:0] fetch_pc, bus_pc, queued_insn;
 reg queued_valid, queued_error, fetch_killed;
 wire consume=state==FETCH && queued_valid;
 wire data_ready=bus_state==BUS_DATA && ready;
 wire redirect=(state==EXEC && !trap && !do_load && !do_store && target!=pc+4)
                || (state==MEMORY && data_ready && !error && !mem_load);
 wire [31:0] redirect_pc=state==MEMORY?next_pc:target;
 assign valid=!rst && !halted && (bus_state==BUS_FETCH || bus_state==BUS_DATA);
 assign fetch=bus_state==BUS_FETCH;
 assign addr=fetch?bus_pc:mem_addr;
 assign wdata=fetch?32'b0:mem_data;
 assign wstrb=bus_state==BUS_DATA?mem_strobes:4'b0;
 assign size=fetch?2'd2:mem_func[1:0];
 always @(posedge clk) begin
  if(rst) begin
   bus_state<=BUS_IDLE; fetch_pc<=RESET_PC; bus_pc<=RESET_PC;
   queued_valid<=0;queued_error<=0;queued_insn<=0;fetch_killed<=0;
  end else begin
   if(consume) queued_valid<=0;
   case(bus_state)
    BUS_IDLE: if(!halted) begin
     if(state==MEMORY) bus_state<=BUS_DATA;
     else if(!queued_valid && !redirect) begin
      bus_pc<=fetch_pc;fetch_killed<=0;bus_state<=BUS_FETCH;
     end
    end
    BUS_FETCH: if(ready) begin
     bus_state<=BUS_GAP;
     if(!fetch_killed) begin
      queued_insn<=rdata;queued_error<=error;queued_valid<=1;fetch_pc<=bus_pc+4;
     end
    end
    BUS_DATA: if(ready) bus_state<=BUS_GAP;
    BUS_GAP: bus_state<=BUS_IDLE;
   endcase
   if(redirect) begin
    fetch_pc<=redirect_pc;queued_valid<=0;
    if(bus_state==BUS_FETCH) fetch_killed<=1;
   end
   if(halted) queued_valid<=0;
  end
 end
 reg signed [65:0] product;
 wire signed [32:0] mul_a={(f3==3)?1'b0:a[31],a};
 wire signed [32:0] mul_b={(f3==2 || f3==3)?1'b0:b[31],b};
 reg [31:0] quotient, divisor, remainder;
 reg [5:0] divide_count;
 reg quotient_negative,remainder_negative;
 wire [32:0] trial={remainder,quotient[31]};
 wire subtract_ok=trial>={1'b0,divisor};
 wire [31:0] remainder_step=subtract_ok?trial-{1'b0,divisor}:trial;
 wire [31:0] quotient_step={quotient[30:0],subtract_ok};
 assign debug_pc=pc;
 always @* begin
  result=0; target=pc+4; ea=0; store_data=0; strobes=0;
  write_rd=0; do_load=0; do_store=0; trap=0; take_branch=0;
  trap_cause=2; trap_value=insn;
  case(insn[6:0])
   7'h37: begin write_rd=1; result={insn[31:12],12'b0}; end
   7'h17: begin write_rd=1; result=pc+{insn[31:12],12'b0}; end
   7'h6f: begin write_rd=1; result=pc+4; target=pc+imm_j; end
   7'h67: begin
    write_rd=1; result=pc+4; target=(a+imm_i)&32'hfffffffe;
    if(f3!=0) trap=1;
   end
   7'h63: begin
    case(f3)
     0: take_branch=a==b; 1: take_branch=a!=b;
     4: take_branch=$signed(a)<$signed(b); 5: take_branch=$signed(a)>=$signed(b);
     6: take_branch=a<b; 7: take_branch=a>=b;
     default: trap=1;
    endcase
    if(take_branch) target=pc+imm_b;
   end
   7'h13: begin
    write_rd=1;
    case(f3)
     0: result=a+imm_i;
     2: result={31'b0,($signed(a)<$signed(imm_i))};
     3: result={31'b0,(a<imm_i)};
     4: result=a^imm_i; 6: result=a|imm_i; 7: result=a&imm_i;
     1: begin result=a<<insn[24:20]; if(f7!=0) trap=1; end
     5: begin
      if(f7==0) result=a>>insn[24:20];
      else if(f7==7'h20) result=$signed(a)>>>insn[24:20];
      else trap=1;
     end
    endcase
   end
   7'h33: begin
    write_rd=1;
    case(f3)
     0: begin
      if(f7==0) result=a+b;
      else if(f7==7'h20) result=a-b;
      else trap=1;
     end
     1: result=a<<b[4:0];
     2: result={31'b0,($signed(a)<$signed(b))};
     3: result={31'b0,(a<b)};
     4: result=a^b;
     5: begin
      if(f7==0) result=a>>b[4:0];
      else if(f7==7'h20) result=$signed(a)>>>b[4:0];
      else trap=1;
     end
     6: result=a|b; 7: result=a&b;
    endcase
    if(f3!=0 && f3!=5 && f7!=0) trap=1;
    if(f7==1) trap=0; // RV32M, handled by registered units
   end
   7'h03: begin
    do_load=1; ea=a+imm_i;
    if(f3!=0 && f3!=1 && f3!=2 && f3!=4 && f3!=5) trap=1;
   end
   7'h23: begin
    do_store=1; ea=a+imm_s; store_data=b<<{ea[1:0],3'b000};
    case(f3)
     0: strobes=4'b0001<<ea[1:0];
     1: strobes=4'b0011<<ea[1:0];
     2: strobes=4'b1111;
     default: trap=1;
    endcase
   end
   7'h0f: if(f3!=0) trap=1; // FENCE is ordered already. No Zifencei.
   7'h73: begin
    trap=1;
    if(insn==32'h00000073) begin trap_cause=11; trap_value=0; end
    else if(insn==32'h00100073) begin trap_cause=3; trap_value=0; end
   end
   default: trap=1;
  endcase
  if(!trap && (do_load || do_store)) begin
   if((f3[1:0]==1 && ea[0]) || (f3[1:0]==2 && ea[1:0]!=0)) begin
    trap=1; trap_cause=do_store?6:4; trap_value=ea;
   end
  end
  if(!trap && target[1:0]!=0) begin trap=1; trap_cause=0; trap_value=target; end
  case(mem_func)
   0: load_result={{24{shifted_read[7]}},shifted_read[7:0]};
   1: load_result={{16{shifted_read[15]}},shifted_read[15:0]};
   4: load_result={24'b0,shifted_read[7:0]};
   5: load_result={16'b0,shifted_read[15:0]};
   default: load_result=shifted_read;
  endcase
 end
 always @(posedge clk) begin
  if(rst) begin
   product<=0;quotient<=0;divisor<=0;remainder<=0;divide_count<=0;
   quotient_negative<=0;remainder_negative<=0;
   a<=0; b<=0; state<=FETCH; pc<=RESET_PC; insn<=0; halted<=0; cause<=0;
   fault_pc<=0; fault_value<=0; retired<=0;
   mem_addr<=0; mem_data<=0; mem_strobes<=0; mem_func<=0;
   mem_rd<=0; mem_load<=0; next_pc<=0;
   for(i=0;i<32;i=i+1) regs[i]<=0;
  end else begin
   retired<=0;
   case(state)
    FETCH: begin
     if(pc[1:0]!=0) begin
      halted<=1; state<=STOP; cause<=0; fault_pc<=pc; fault_value<=pc;
     end else if(queued_valid) begin
      if(queued_error) begin halted<=1; state<=STOP; cause<=1; fault_pc<=pc; fault_value<=pc; end
      else begin insn<=queued_insn; state<=DECODE; end
     end
    end
    DECODE: begin
     a<=(rs1==0)?32'b0:regs[rs1];
     b<=(rs2==0)?32'b0:regs[rs2];
     state<=EXEC;
    end
    EXEC: begin
     if(trap) begin
      halted<=1; state<=STOP; cause<=trap_cause; fault_pc<=pc; fault_value<=trap_value;
     end else if(insn[6:0]==7'h33 && f7==1) begin
      if(!f3[2]) begin product<=mul_a*mul_b; state<=MULT; end
      else begin
       quotient<=(!f3[0] && a[31])?-a:a;
       divisor<=(!f3[0] && b[31])?-b:b;
       remainder<=0;divide_count<=0;
       quotient_negative<=!f3[0] && (a[31]^b[31]) && b!=0;
       remainder_negative<=!f3[0] && a[31];state<=DIVIDE;
      end
     end else if(do_load || do_store) begin
      mem_addr<=ea; mem_data<=store_data; mem_strobes<=strobes;
      mem_func<=f3; mem_rd<=rd; mem_load<=do_load; next_pc<=target; state<=MEMORY;
     end else begin
      if(write_rd && rd!=0) regs[rd]<=result;
      pc<=target; state<=FETCH; retired<=1;
     end
    end
    MEMORY: if(data_ready) begin
     if(error) begin
      halted<=1; state<=STOP; cause<=mem_load?5:7; fault_pc<=pc; fault_value<=mem_addr;
     end else begin
      if(mem_load && mem_rd!=0) regs[mem_rd]<=load_result;
      pc<=next_pc; state<=GAP; retired<=1;
     end
    end
    MULT: begin
     if(rd!=0) regs[rd]<=f3==0?product[31:0]:product[63:32];
     pc<=pc+4;state<=FETCH;retired<=1;
    end
    DIVIDE: begin
     quotient<=quotient_step;remainder<=remainder_step;divide_count<=divide_count+1'b1;
     if(divide_count==31) begin
      if(rd!=0) regs[rd]<=f3[1]?(remainder_negative?-remainder_step:remainder_step):
                                              (quotient_negative?-quotient_step:quotient_step);
      pc<=pc+4;state<=FETCH;retired<=1;
     end
    end
    GAP: state<=FETCH; // deassert valid for MMIO rearm
    default: state<=STOP;
   endcase
  end
 end
endmodule
