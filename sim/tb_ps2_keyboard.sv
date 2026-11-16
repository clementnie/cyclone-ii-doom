`timescale 1ns/1ps
module tb_ps2_keyboard;
    parameter integer CLK_HZ = 50000000;
    localparam real CLK_PERIOD = 1000000000.0 / CLK_HZ;
    reg clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;
    reg rst = 1;
    reg ps2_clk = 1, ps2_data = 1;
    reg bus_valid = 0;
    reg [11:0] bus_addr = 0;
    reg [31:0] bus_wdata = 0;
    reg [3:0] bus_wstrb = 0;
    wire bus_ready, bus_error;
    wire [31:0] bus_rdata;
    integer checks = 0;
    integer completions = 0;
    integer i;
    reg [31:0] value;
    ps2_keyboard_mmio #(.CLK_HZ(CLK_HZ)) dut (.*);
    always @(posedge clk)
        if (bus_ready) completions <= completions + 1;

    task check(input bit condition, input string description);
        begin
            checks = checks + 1;
            if (!condition) $fatal(1, "%s (clk=%0d, time=%0t)", description, CLK_HZ, $time);
        end
    endtask
    // 12.5-kHz external clock, asynchronous phase relative to system clock.
    task send_bit(input bit data_bit);
        begin
            ps2_clk = 1; ps2_data = data_bit;
            #40003; ps2_clk = 0;
            #39997; ps2_clk = 1;
        end
    endtask
    task send_frame(input [7:0] data, input bit bad_parity, input bit bad_stop);
        integer b;
        begin
            send_bit(0);
            for (b=0; b<8; b=b+1) send_bit(data[b]);
            send_bit((~^data) ^ bad_parity);
            send_bit(!bad_stop);
            ps2_data = 1;
            #80000;
        end
    endtask
    task scan(input [7:0] data);
        begin send_frame(data, 0, 0); end
    endtask
    task key_sequence(input bit extended, input bit release_key, input [7:0] code);
        begin
            if (extended) scan(8'he0);
            if (release_key) scan(8'hf0);
            scan(code);
        end
    endtask
    task access(input [11:0] addr, input [3:0] strobes, input [31:0] data,
                input bit expected_error, input integer held_cycles, output [31:0] result);
        integer before_count, j;
        begin
            @(negedge clk);
            bus_valid = 1; bus_addr = addr; bus_wstrb = strobes; bus_wdata = data;
            #1;
            check(bus_ready, "bus accepts fresh request");
            check(bus_error == expected_error, "bus error matches access");
            result = bus_rdata;
            before_count = completions;
            @(posedge clk); #1;
            check(!bus_ready, "held valid is not acknowledged twice");
            for (j=0; j<held_cycles; j=j+1) begin
                @(posedge clk); #1;
                check(!bus_ready, "request remains completed while held");
            end
            check(completions == before_count+1, "exactly one MMIO completion");
            @(negedge clk); bus_valid = 0; bus_wstrb = 0;
            @(posedge clk); #1;
        end
    endtask
    task read_reg(input [11:0] addr, output [31:0] result);
        begin access(addr, 0, 0, 0, 0, result); end
    endtask
    task clear(input [31:0] mask);
        reg [31:0] unused;
        begin access(12'h008, 4'hf, mask, 0, 0, unused); end
    endtask
    task expect_event(input bit pressed, input [7:0] key_id);
        reg [31:0] result;
        begin
            read_reg(0, result);
            check(result == (32'h80000000 | (pressed << 8) | key_id), "mapped event and press/release polarity");
        end
    endtask
    task expect_empty;
        reg [31:0] result;
        begin
            read_reg(4, result); check(result[5:0] == 0 && !result[8], "FIFO empty status");
            read_reg(0, result); check(result == 0, "empty read has no valid flag");
        end
    endtask
    task reset_dut;
        begin
            @(negedge clk); rst = 1; ps2_clk = 1; ps2_data = 1;
            repeat (5) @(negedge clk);
            rst = 0; repeat (20) @(negedge clk);
        end
    endtask

    initial begin
        reset_dut();
        expect_empty();
        // Each requested key: make, duplicate make, break, duplicate break.
        for (i=0; i<7; i=i+1) begin
            case (i)
                0: value = 8'h75;
                1: value = 8'h72;
                2: value = 8'h6b;
                3: value = 8'h74;
                4: value = 8'h14;
                5: value = 8'h29;
                6: value = 8'h76;
            endcase
            key_sequence(i<4, 0, value[7:0]);
            key_sequence(i<4, 0, value[7:0]);
            read_reg(12'h00c, value);
            check(value == (1 << i), "held state reflects selected key");
            case (i)
                0: value = 8'h75;
                1: value = 8'h72;
                2: value = 8'h6b;
                3: value = 8'h74;
                4: value = 8'h14;
                5: value = 8'h29;
                6: value = 8'h76;
            endcase
            key_sequence(i<4, 1, value[7:0]);
            key_sequence(i<4, 1, value[7:0]);
            expect_event(1, i); expect_event(0, i); expect_empty();
        end
        // Simultaneous movement + fire + use, including both Ctrl keys.
        key_sequence(1, 0, 8'h75);
        key_sequence(0, 0, 8'h14);
        key_sequence(1, 0, 8'h14);
        key_sequence(0, 0, 8'h29);
        key_sequence(0, 1, 8'h14);
        read_reg(12'h00c, value); check(value == 7'h31, "right Ctrl retains fire with left released");
        key_sequence(1, 1, 8'h14);
        key_sequence(1, 1, 8'h75);
        key_sequence(0, 1, 8'h29);
        expect_event(1,0); expect_event(1,4); expect_event(1,5);
        expect_event(0,4); expect_event(0,0); expect_event(0,5); expect_empty();
        // Plain keypad arrows, unknown keys, BAT/ACK and Pause do not fire.
        scan(8'h75); scan(8'h72); scan(8'h6b); scan(8'h74); scan(8'h1c);
        scan(8'haa); scan(8'hfa);
        scan(8'he1); scan(8'h14); scan(8'h77); scan(8'he1);
        scan(8'hf0); scan(8'h14); scan(8'hf0); scan(8'h77);
        expect_empty();
        read_reg(12'h00c, value); check(value == 0, "Pause does not hold Ctrl");
        // Parity, stop, bad start, partial-frame timeout, prefix recovery.
        send_frame(8'h29, 1, 0); send_frame(8'h76, 0, 1);
        send_bit(1); ps2_data = 1; #80000;
        send_bit(0); send_bit(1); ps2_data = 1; #2500000;
        expect_empty(); read_reg(4, value); check(value[10], "RX faults latched");
        clear(2); read_reg(4, value); check(!value[10], "RX fault W1C");
        scan(8'he0); send_frame(8'h75, 1, 0); scan(8'h75);
        expect_empty(); // bad extended frame must consume prefix state
        clear(2);
        scan(8'hf0); #21000000;
        read_reg(4, value); check(value[10], "dangling prefix times out");
        scan(8'h29); expect_event(1,5);
        key_sequence(0,1,8'h29); expect_event(0,5); clear(2);
        // A sub-filter clock glitch with DATA low must not start a frame.
        ps2_data = 0; #1000;
        ps2_clk = 0; #(CLK_PERIOD*2); ps2_clk = 1; #1000; ps2_data = 1;
        #2500000; read_reg(4, value); check(!value[10], "clock glitch rejected");
        expect_empty();
        // A held bus request must pop only one of two queued events.
        scan(8'h29); key_sequence(0,1,8'h29);
        access(0,0,0,0,5,value); check(value == 32'h80000105, "held request gets first event");
        expect_event(0,5); expect_empty();
        // FIFO wrap and overflow: preserve oldest events, latch loss.
        for (i=0; i<36; i=i+1) key_sequence(0, i%2 != 0, 8'h29);
        read_reg(4,value); check(value[5:0] == 32 && value[9], "full FIFO drops newest and reports overflow");
        read_reg(12'h00c,value); check(value == 0, "key snapshot updates even on dropped events");
        clear(1); read_reg(4,value); check(!value[9], "overflow W1C");
        // Accept one more event on exactly the edge that pops a full FIFO.
        fork
            scan(8'h29);
            begin
                @(posedge dut.decoded_valid);
                access(0,0,0,0,0,value);
                check(value == 32'h80000105, "full simultaneous pop returns oldest event");
            end
        join
        read_reg(4,value);
        check(value[5:0] == 32 && !value[9], "full simultaneous push/pop preserves count without overflow");
        for (i=0; i<31; i=i+1) expect_event(i%2 != 0,5);
        expect_event(1,5); expect_empty();
        key_sequence(0,1,8'h29); expect_event(0,5);
        // Reading an empty queue while a new event arrives leaves it queued.
        fork
            scan(8'h29);
            begin
                @(posedge dut.decoded_valid);
                access(0,0,0,0,0,value);
                check(value == 0, "empty simultaneous read reports no prior event");
            end
        join
        expect_event(1,5); key_sequence(0,1,8'h29); expect_event(0,5);
        scan(8'h76); clear(15); expect_empty();
        read_reg(12'h00c,value); check(value == 0, "software recovery clears held state");
        // Malformed accesses complete with an error and have no effects.
        scan(8'h29);
        access(12'h001,0,0,1,0,value);
        access(12'h000,4'hf,0,1,0,value);
        access(12'h008,4'h1,15,1,0,value);
        access(12'h010,0,0,1,0,value);
        expect_event(1,5); clear(15);
        // Reset with queued data and partial frame clears all state.
        scan(8'h76); send_bit(0); send_bit(1);
        reset_dut(); expect_empty(); read_reg(12'h00c,value); check(value == 0, "reset clears held keys");
        key_sequence(1,0,8'h74); expect_event(1,3);
        key_sequence(1,1,8'h74); expect_event(0,3); expect_empty();
        $display("PASS: PS/2 integration CLK_HZ=%0d checks=%0d", CLK_HZ, checks);
        $finish;
    end
    initial begin #500000000; $fatal(1,"global simulation timeout"); end
endmodule
