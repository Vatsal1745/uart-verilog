`timescale 1ns/1ps

module uart_top # (
    parameter clk_freq = 50000000,
    parameter baud_rate = 9600,
    parameter PARITY_TYPE = 0       // 0 for Even Parity, 1 for Odd Parity
)(
    input wire       clk,
    input wire       reset,         // Top-level board reset pin
    
    // Transmitter Interface Ports
    input wire       tx_start,
    input wire [7:0] tx_data,
    output wire      tx_serial,     // Physical outbound loop monitor pin
    output wire      tx_done,       // Connects to tx_busy status inversion
    
    // Receiver Interface Ports
    output wire      rx_done,
    output wire      parity_error,
    output wire [7:0] rx_data       
);

    // Internal Wire Routing Matrices
    wire s_tick;                    // Master 16x oversampling clock tick
    wire loopback_wire;             // Internal connection from tx output to rx input
    wire tx_busy_status;            // Captures your transmitter's busy signal

    //-------------------------------------------------------------------------
    // 1. Instantiation: The Master Timing Engine (16x Oversampling Mode)
    //-------------------------------------------------------------------------
    baud_gen #(
        .clk_freq(clk_freq),
        .baud_rate(baud_rate),
        .oversample(16)             
    ) master_baud_engine (
        .clk(clk),
        .reset(reset),
        .baud_tick(s_tick)          
    );

    //-------------------------------------------------------------------------
    // 2. Hardware Tick Divider: Creating the 1x Tx Pulse from the 16x Rx Pulse
    //-------------------------------------------------------------------------
    reg [3:0] tx_tick_counter;      
    reg       tx_tick;              

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_tick_counter <= 4'd0;
            tx_tick         <= 1'b0;
        end else begin
            tx_tick <= 1'b0;        
            if (s_tick) begin
                if (tx_tick_counter == 4'd15) begin
                    tx_tick_counter <= 4'd0;
                    tx_tick         <= 1'b1; 
                end else begin
                    tx_tick_counter <= tx_tick_counter + 1'b1;
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // 3. Instantiation: The Transmitter Module (Mapped to your exact port list)
    //-------------------------------------------------------------------------
    uart_tx transmitter_core (
        .clk(clk),
        .rst(reset),                 // Maps your 'rst' input to top-level reset
        .baud_tick(tx_tick),
        .tx_start(tx_start),
        .data_in(tx_data),           // Maps your 'data_in' input to top tx_data bus
        .tx_out(loopback_wire),      // Maps your 'tx_out' line to loopback trace
        .tx_busy(tx_busy_status)     // Capture the busy status wire
    );

    // Map external pins to match your testbench environment expectations
    assign tx_serial = loopback_wire;
    assign tx_done   = ~tx_busy_status; // Done when not busy

    //-------------------------------------------------------------------------
    // 4. Instantiation: The Receiver Module
    //-------------------------------------------------------------------------
    uart_rx #(
        .clk_freq(clk_freq),
        .baud_rate(baud_rate),
        .oversample(16),
        .PARITY_TYPE(PARITY_TYPE)
    ) receiver_core (
        .clk(clk),
        .reset(reset),
        .rx(loopback_wire),         // Listens directly to your tx_out trace!
        .s_tick(s_tick),            
        .rx_done(rx_done),
        .parity_error(parity_error),
        .rx_data(rx_data)
    );

endmodule