`timescale 1ns/1ps

module uart_top_tb;

    // 1. Testbench Signals
    reg        tb_clk;
    reg        tb_reset;
    reg        tb_tx_start;
    reg  [7:0] tb_tx_data;
    wire       tb_tx_serial;
    wire       tb_tx_done;
    wire       tb_rx_done;
    wire       tb_parity_error;
    wire [7:0] tb_rx_data;

    // 2. Instantiate the Complete Loopback System Module
    uart_top #(
        .clk_freq(1000000),    // 1 MHz simulation clock
        .baud_rate(9600),      // 9600 Baud
        .PARITY_TYPE(0)        // Even Parity Mode
    ) uut_top (
        .clk(tb_clk),
        .reset(tb_reset),
        .tx_start(tb_tx_start),
        .tx_data(tb_tx_data),
        .tx_serial(tb_tx_serial),
        .tx_done(tb_tx_done),
        .rx_done(tb_rx_done),
        .parity_error(tb_parity_error),
        .rx_data(tb_rx_data)
    );

    // 3. Generate 1 MHz Master System Clock (1000ns period)
    always begin
        #500 tb_clk = ~tb_clk;
    end

    // 4. Test Execution Timeline
    initial begin
        $dumpfile("top_waveform.vcd");
        $dumpvars(0, uart_top_tb);
        
        // Initial State
        tb_clk      = 0;
        tb_reset    = 1;
        tb_tx_start = 0;
        tb_tx_data  = 8'd0;
        #2000;
        
        // Release Reset
        tb_reset = 0;
        #5000;
        
        // --- TEST CASE 1: Send your target 10101010 pattern through the loop ---
        $display("[SYSTEM TEST] Loading 0xAA (8'b10101010) into Transmitter...");
        tb_tx_data  = 8'hAA;
        tb_tx_start = 1;        // Press the transmit button
        #1000;                  // Hold for 1 clock cycle pulse
        tb_tx_start = 0;        // Release button
        
        // Wait for the loopback to complete processing
        // 11 bits total (1 start + 8 data + 1 parity + 1 stop) at 9600 baud takes ~1.15ms
        @(posedge tb_rx_done);  // Pause execution until the receiver finishes parsing
        #10000;                 // Hold view window
        
        $display("[SYSTEM TEST] Success! Received Parallel Byte: 0x%h", tb_rx_data);
        $display("[SYSTEM TEST] Parity Error Status: %b", tb_parity_error);
        
        #50000;
        $display("[SIM COMPLETE] Top Level Loopback Verified.");
        $finish;
    end

endmodule