`timescale 1ns/1ps
// Set-2 subset for DOOM. IDs: up=0, down=1, left=2, right=3,
// fire(Ctrl)=4, use(Space)=5, menu(Esc)=6. event_data={pressed,id[7:0]}.
module ps2_scancode_decoder #(
    parameter integer CLK_HZ = 50000000,
    parameter integer PREFIX_TIMEOUT_CYCLES = CLK_HZ / 50
)(
    input wire clk, input wire rst,
    input wire [7:0] byte_data, input wire byte_valid,
    input wire abort_sequence,
    output reg [8:0] event_data, output reg event_valid,
    output reg [6:0] keys_down,
    output reg sequence_error
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
    localparam integer TIMER_BITS = bits_for(PREFIX_TIMEOUT_CYCLES);
    reg extended, release_prefix;
    reg [2:0] pause_skip;
    reg [TIMER_BITS-1:0] prefix_timer;
    reg left_ctrl, right_ctrl;
    reg mapped;
    reg [2:0] key_id;
    reg new_state;

    always @* begin
        mapped = 1;
        key_id = 0;
        new_state = !release_prefix;
        if (extended) begin
            case (byte_data)
                8'h75: key_id = 0;
                8'h72: key_id = 1;
                8'h6b: key_id = 2;
                8'h74: key_id = 3;
                8'h14: begin
                    key_id = 4;
                    new_state = left_ctrl || !release_prefix;
                end
                default: mapped = 0;
            endcase
        end else begin
            case (byte_data)
                8'h14: begin
                    key_id = 4;
                    new_state = right_ctrl || !release_prefix;
                end
                8'h29: key_id = 5;
                8'h76: key_id = 6;
                default: mapped = 0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            extended <= 0;
            release_prefix <= 0;
            pause_skip <= 0;
            prefix_timer <= 0;
            left_ctrl <= 0;
            right_ctrl <= 0;
            keys_down <= 0;
            event_data <= 0;
            event_valid <= 0;
            sequence_error <= 0;
        end else begin
            event_valid <= 0;
            sequence_error <= 0;
            if (abort_sequence) begin
                extended <= 0;
                release_prefix <= 0;
                pause_skip <= 0;
                prefix_timer <= 0;
            end else if (byte_valid) begin
                prefix_timer <= 0;
                if (pause_skip != 0) pause_skip <= pause_skip - 1'b1;
                else if (byte_data == 8'he1) begin
                    // Pause contains 14: do not synthesize a Ctrl/fire event.
                    pause_skip <= 7;
                    extended <= 0;
                    release_prefix <= 0;
                end else if (byte_data == 8'he0) extended <= 1;
                else if (byte_data == 8'hf0) release_prefix <= 1;
                else begin
                    if (mapped) begin
                        if (byte_data == 8'h14) begin
                            if (extended) right_ctrl <= !release_prefix;
                            else left_ctrl <= !release_prefix;
                        end
                        if (keys_down[key_id] != new_state) begin
                            keys_down[key_id] <= new_state;
                            event_data <= {new_state, 5'b0, key_id};
                            event_valid <= 1;
                        end
                    end
                    // Any non-prefix byte consumes E0/F0, even if unmapped.
                    extended <= 0;
                    release_prefix <= 0;
                end
            end else if (extended || release_prefix || pause_skip != 0) begin
                if (prefix_timer == PREFIX_TIMEOUT_CYCLES-1) begin
                    extended <= 0;
                    release_prefix <= 0;
                    pause_skip <= 0;
                    prefix_timer <= 0;
                    sequence_error <= 1;
                end else prefix_timer <= prefix_timer + 1'b1;
            end else prefix_timer <= 0;
        end
    end
endmodule
