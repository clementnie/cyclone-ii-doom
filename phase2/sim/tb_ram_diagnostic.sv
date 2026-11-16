`timescale 1ns/1ps
module tb_ram_diagnostic;
 reg clk=0; always #10 clk=~clk;
 reg rst=1;
 wire [31:0] hb,boot_hb;
 wire halted,boot_halted;
 phase2_soc bad_ram(.clk(clk),.rst(rst),.ps2_clk(1'b1),.ps2_data(1'b1),.mailbox(hb),.halted(halted));
 phase2_soc bad_init(.clk(clk),.rst(rst),.ps2_clk(1'b1),.ps2_data(1'b1),.mailbox(boot_hb),.halted(boot_halted));
 initial begin
  // Corrupt all data reads, including the startup initialized-data check.
  force bad_init.fabric.memory.ram_q=0;
  repeat(5) @(negedge clk); rst=0;
  wait(boot_halted);
  if(bad_init.fabric.diag_error!==32'he001 || bad_init.fabric.ram_result!==0)
   $fatal(1,"startup corruption must never report PASS");
  wait(hb==1);
  // After startup validation, emulate a stuck-zero RAM read port.
  force bad_ram.fabric.memory.ram_q=0;
  wait(bad_ram.fabric.ram_result==2);
  wait(bad_ram.fabric.diag_error==32'he002);
  if(halted) $fatal(1,"RAM failure should retain firmware diagnostics");
  wait(hb>=2);
  if(bad_ram.fabric.ram_result!==2 || bad_ram.fabric.diag_error!==32'he002)
   $fatal(1,"RAM failure not retained");
  $display("PASS RAM diagnostics: startup corruption NOT TESTED/E001; stuck-zero scratch FAIL/E002; heartbeat survives failure");
  $finish;
 end
 initial begin #50000000; $fatal(1,"RAM fault injection timeout"); end
endmodule
