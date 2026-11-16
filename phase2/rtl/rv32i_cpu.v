`timescale 1ns/1ps
// Blocking multicycle RV32I, IALIGN=32. Traps stop until reset.
module rv32i_cpu #(parameter RESET_PC=32'h00000000)(
 input wire clk, rst,
 output wire valid, fetch, output wire [31:0] addr, wdata,
 output wire [3:0] wstrb, output wire [1:0] size,
 input wire ready, error, input wire [31:0] rdata,
 output reg halted, output reg [3:0] cause,
 output reg [31:0] fault_pc, fault_value,
 output wire [31:0] debug_pc, output reg retired
);
 localparam FETCH=0, EXEC=1, MEMORY=2, GAP=3, STOP=4;
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
 wire [31:0] a=(rs1==0)?32'b0:regs[rs1];
 wire [31:0] b=(rs2==0)?32'b0:regs[rs2];
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
 assign valid=!rst && (state==FETCH || state==MEMORY);
 assign fetch=state==FETCH;
 assign addr=(state==FETCH)?pc:mem_addr;
 assign wdata=mem_data;
 assign wstrb=(state==MEMORY)?mem_strobes:4'b0;
 assign size=(state==FETCH)?2'd2:mem_func[1:0];
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
   state<=FETCH; pc<=RESET_PC; insn<=0; halted<=0; cause<=0;
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
     end else if(ready) begin
      if(error) begin halted<=1; state<=STOP; cause<=1; fault_pc<=pc; fault_value<=pc; end
      else begin insn<=rdata; state<=EXEC; end
     end
    end
    EXEC: begin
     if(trap) begin
      halted<=1; state<=STOP; cause<=trap_cause; fault_pc<=pc; fault_value<=trap_value;
     end else if(do_load || do_store) begin
      mem_addr<=ea; mem_data<=store_data; mem_strobes<=strobes;
      mem_func<=f3; mem_rd<=rd; mem_load<=do_load; next_pc<=target; state<=MEMORY;
     end else begin
      if(write_rd && rd!=0) regs[rd]<=result;
      pc<=target; state<=FETCH; retired<=1;
     end
    end
    MEMORY: if(ready) begin
     if(error) begin
      halted<=1; state<=STOP; cause<=mem_load?5:7; fault_pc<=pc; fault_value<=mem_addr;
     end else begin
      if(mem_load && mem_rd!=0) regs[mem_rd]<=load_result;
      pc<=next_pc; state<=GAP; retired<=1;
     end
    end
    GAP: state<=FETCH; // deassert valid for MMIO rearm
    default: state<=STOP;
   endcase
  end
 end
endmodule
