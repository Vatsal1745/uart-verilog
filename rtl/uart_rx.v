`timescale 1ns/1ps

module uart_rx # (
    parameter clk_freq = 50000000,
    parameter baud_rate = 9600,
    parameter oversample = 16,     // Matching your Day 2 oversample parameter
    parameter PARITY_TYPE = 0      // 0 for Even Parity, 1 for Odd Parity
)(
    input wire clk,
    input wire reset,
    input wire rx,
    input wire s_tick,             // 16x oversampling clock tick from baud_gen
    output reg rx_done,
    output reg parity_error,
    output reg [7:0] rx_data       // 8-bit output data payload
);

    // FSM State Encodings (3-bit matching your FSM tracking)
    localparam [2:0] IDLE   = 3'b000,
                     START  = 3'b001,
                     DATA   = 3'b010,
                     PARITY = 3'b011,
                     STOP   = 3'b100;

    // Internal Registers (Matching your structural style)
    reg [2:0] current_state, next_state;
    reg [3:0] s_count;         // Counts 16 slices per serial bit (0 to 15)
    reg [2:0] bit_index;       // Tracks 8 data payload bits (0 to 7)
    reg [7:0] data_buffer;     // Shift register for deserializing incoming data
    reg       parity_bit;      // Captures the parity bit directly from the rx wire

    // Reduction XOR logic matching your transmitter's parity system
    wire calc_parity;
    assign calc_parity = (PARITY_TYPE == 0) ? ^data_buffer : ~(^data_buffer);

    //-------------------------------------------------------------------------
    // 1. Sequential Logic Block (State & Counter Updates)
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            s_count       <= 4'd0;
            bit_index     <= 3'd0;
            data_buffer   <= 8'd0;
            parity_bit    <= 1'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    s_count   <= 4'd0;
                    bit_index <= 3'd0;
                end
                
                START: begin
                    if (s_tick) begin
                        if (s_count == 4'd7) begin
                            s_count   <= 4'd0; // Reset slice counter for Data phase
                            bit_index <= 3'd0; // Reset index pointer
                        end else begin
                            s_count   <= s_count + 1'b1;
                        end
                    end
                end
                
                DATA: begin
                    if (s_tick) begin
                        if (s_count == 4'd15) begin
                            s_count     <= 4'd0;
                            data_buffer <= {rx, data_buffer[7:1]}; // Deserializing LSB-first
                            if (bit_index == 3'd7)
                                bit_index <= 3'd0;
                            else
                                bit_index <= bit_index + 1'b1;
                        end else begin
                            s_count <= s_count + 1'b1;
                        end
                    end
                end

                PARITY: begin
                    if (s_tick) begin
                        if (s_count == 4'd15) begin
                            s_count    <= 4'd0;
                            parity_bit <= rx; // Latch the parity bit value from line
                        end else begin
                            s_count <= s_count + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (s_tick) begin
                        if (s_count == 4'd15) begin
                            s_count <= 4'd0;
                        end else begin
                            s_count <= s_count + 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // 2. Combinational Next-State Logic Block
    //-------------------------------------------------------------------------
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (~rx) // Low start bit edge detected
                    next_state = START;
            end
            
            START: begin
                if (s_tick && (s_count == 4'd7))
                    next_state = DATA;
            end
            
            DATA: begin
                if (s_tick && (s_count == 4'd15) && (bit_index == 3'd7))
                    next_state = PARITY;
            end
            
            PARITY: begin
                if (s_tick && (s_count == 4'd15))
                    next_state = STOP;
            end
            
            STOP: begin
                if (s_tick && (s_count == 4'd15))
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    //-------------------------------------------------------------------------
    // 3. Registered Look-Ahead Output Logic
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_done      <= 1'b0;
            rx_data      <= 8'd0;
            parity_error <= 1'b0;
        end else begin
            // Pulse rx_done only on the final step exiting the STOP state
            if ((current_state == STOP) && s_tick && (s_count == 4'd15)) begin
                rx_done      <= 1'b1;
                rx_data      <= data_buffer;
                parity_error <= (parity_bit != calc_parity); // Flag if mismatch occurs
            end else begin
                rx_done <= 1'b0; // Auto-clear to maintain single clock cycle pulse
            end
        end
    end

endmodule