`timescale 1ns/1ps
// Standalone peripheral; future SoC decode selects 0x10002000..0x10002fff.
// valid must go low between transactions. A held request completes once.
module ps2_keyboard_mmio #(
    parameter integer CLK_HZ = 50000000,
    parameter integer FILTER_CYCLES = 8
)(
    input wire clk, input wire rst,
    input wire ps2_clk, input wire ps2_data,
    input wire bus_valid, input wire [11:0] bus_addr,
    input wire [31:0] bus_wdata, input wire [3:0] bus_wstrb,
    output wire bus_ready, output reg [31:0] bus_rdata,
    output reg bus_error
);
    wire [7:0] received_byte;
    wire received_valid, frame_error, sequence_error;
    wire [8:0] decoded_event;
    wire decoded_valid;
    wire [6:0] keys_down;
    reg [8:0] fifo [0:31];
    reg [4:0] read_pointer, write_pointer;
    reg [5:0] count;
    reg overflow_sticky, error_sticky, served;
    wire [8:0] fifo_head = fifo[read_pointer];
    wire is_write = |bus_wstrb;
    wire clear_write = bus_ready && !bus_error && is_write && bus_addr == 12'h008;
    wire flush_fifo = clear_write && bus_wdata[2];
    wire clear_decoder = clear_write && bus_wdata[3];
    wire pop = bus_ready && !bus_error && !is_write && bus_addr == 0 && count != 0;
    wire push = decoded_valid && (count < 32 || pop);
    assign bus_ready = bus_valid && !served && !rst;

    ps2_receiver #(.CLK_HZ(CLK_HZ), .FILTER_CYCLES(FILTER_CYCLES)) rx (
        .clk(clk), .rst(rst || clear_decoder), .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .byte_data(received_byte), .byte_valid(received_valid), .frame_error(frame_error)
    );
    ps2_scancode_decoder #(.CLK_HZ(CLK_HZ)) decoder (
        .clk(clk), .rst(rst || clear_decoder), .byte_data(received_byte),
        .byte_valid(received_valid), .abort_sequence(frame_error),
        .event_data(decoded_event), .event_valid(decoded_valid),
        .keys_down(keys_down), .sequence_error(sequence_error)
    );

    always @* begin
        bus_rdata = 0;
        bus_error = 0;
        if (is_write) begin
            if (bus_addr != 12'h008 || bus_wstrb != 4'hf) bus_error = 1;
        end else begin
            case (bus_addr)
                12'h000: if (count != 0) bus_rdata = {1'b1, 22'b0, fifo_head};
                12'h004: bus_rdata = {21'b0, error_sticky, overflow_sticky,
                                      (count != 0), 2'b0, count};
                12'h008: bus_rdata = 0;
                12'h00c: bus_rdata = {25'b0, keys_down};
                default: bus_error = 1;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            read_pointer <= 0;
            write_pointer <= 0;
            count <= 0;
            overflow_sticky <= 0;
            error_sticky <= 0;
            served <= 0;
        end else begin
            if (!bus_valid) served <= 0;
            else if (bus_ready) served <= 1;
            if (clear_write && bus_wdata[0]) overflow_sticky <= 0;
            if (clear_write && bus_wdata[1]) error_sticky <= 0;
            // A new error wins over simultaneous software error clear.
            if (frame_error || sequence_error) error_sticky <= 1;
            if (flush_fifo || clear_decoder) begin
                read_pointer <= 0;
                write_pointer <= 0;
                count <= 0;
            end else begin
                if (decoded_valid && !push) overflow_sticky <= 1;
                if (push) begin
                    fifo[write_pointer] <= decoded_event;
                    write_pointer <= write_pointer + 1'b1;
                end
                if (pop) read_pointer <= read_pointer + 1'b1;
                case ({push, pop})
                    2'b10: count <= count + 1'b1;
                    2'b01: count <= count - 1'b1;
                    default: count <= count;
                endcase
            end
        end
    end
endmodule
