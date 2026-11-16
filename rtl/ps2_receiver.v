`timescale 1ns/1ps
// Receive-only PS/2. rst is synchronous, active high. No external line drivers.
module ps2_receiver #(
    parameter integer CLK_HZ = 50000000,
    parameter integer FILTER_CYCLES = 8,
    parameter integer TIMEOUT_CYCLES = CLK_HZ / 500
)(
    input wire clk, input wire rst,
    input wire ps2_clk, input wire ps2_data,
    output reg [7:0] byte_data,
    output reg byte_valid, output reg frame_error
);
    function integer bits_for;
        input integer n;
        integer v;
        begin
            bits_for = 1;
            for (v = n - 1; v > 1; v = v >> 1)
                bits_for = bits_for + 1;
        end
    endfunction
    localparam integer TIMER_BITS = bits_for(TIMEOUT_CYCLES);
    // Keep these two-stage chains visible for later Quartus CDC assignment.
    reg [1:0] clock_sync, data_sync;
    reg [FILTER_CYCLES-1:0] clock_history, data_history;
    reg clock_filtered, data_filtered, clock_previous;
    reg [3:0] bit_index;
    reg [7:0] shift_data;
    reg parity_xor, parity_ok;
    reg [TIMER_BITS-1:0] idle_count;
    wire falling_edge = clock_previous && !clock_filtered;

    always @(posedge clk) begin
        if (rst) begin
            clock_sync <= 2'b11;
            data_sync <= 2'b11;
            clock_history <= {FILTER_CYCLES{1'b1}};
            data_history <= {FILTER_CYCLES{1'b1}};
            clock_filtered <= 1'b1;
            data_filtered <= 1'b1;
            clock_previous <= 1'b1;
            byte_data <= 0;
            byte_valid <= 0;
            frame_error <= 0;
            bit_index <= 0;
            shift_data <= 0;
            parity_xor <= 0;
            parity_ok <= 0;
            idle_count <= 0;
        end else begin
            clock_sync <= {clock_sync[0], ps2_clk};
            data_sync <= {data_sync[0], ps2_data};
            clock_history <= (clock_history << 1) | clock_sync[1];
            data_history <= (data_history << 1) | data_sync[1];
            if (&clock_history) clock_filtered <= 1;
            else if (~|clock_history) clock_filtered <= 0;
            if (&data_history) data_filtered <= 1;
            else if (~|data_history) data_filtered <= 0;
            clock_previous <= clock_filtered;
            byte_valid <= 0;
            frame_error <= 0;

            if (falling_edge) begin
                idle_count <= 0;
                if (bit_index == 0) begin
                    if (!data_filtered) begin
                        bit_index <= 1;
                        parity_xor <= 0;
                    end else frame_error <= 1;
                end else if (bit_index <= 8) begin
                    shift_data[bit_index-1] <= data_filtered;
                    parity_xor <= parity_xor ^ data_filtered;
                    bit_index <= bit_index + 1'b1;
                end else if (bit_index == 9) begin
                    parity_ok <= parity_xor ^ data_filtered;
                    bit_index <= 10;
                end else begin
                    bit_index <= 0;
                    if (data_filtered && parity_ok) begin
                        byte_data <= shift_data;
                        byte_valid <= 1;
                    end else frame_error <= 1;
                end
            end else if (bit_index != 0) begin
                if (idle_count == TIMEOUT_CYCLES-1) begin
                    bit_index <= 0;
                    idle_count <= 0;
                    frame_error <= 1;
                end else idle_count <= idle_count + 1'b1;
            end else idle_count <= 0;
        end
    end
endmodule
