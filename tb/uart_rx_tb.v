`timescale 1ns/1ps

module uart_rx_tb;

    // 1. Testbench Signals
    reg        tb_clk;
    reg        tb_reset;
    reg        tb_rx;
    wire       tb_s_tick;
    wire       tb_rx_done;
    wire       tb_parity_error;
    wire [7:0] tb_rx_data;

    // 2. Instantiate the Clock/Timing Engine (Configured for 16x Oversampling)
    baud_gen #(
        .clk_freq(1000000),    // 1 MHz fake clock to keep simulation tight
        .baud_rate(9600),      // 9600 Baud
        .oversample(16)        // 16x oversampling mode enabled for RX support
    ) uut_baud (
        .clk(tb_clk),
        .reset(tb_reset),
        .baud_tick(tb_s_tick)  // Feeds the 16x oversample ticks directly to the RX
    );

    // 3. Instantiate your Re-Engineered Receiver Module
    uart_rx #(
        .clk_freq(1000000),
        .baud_rate(9600),
        .oversample(16),
        .PARITY_TYPE(0)        // 0 for Even Parity (Matches our test vector calculation)
    ) uut_rx (
        .clk(tb_clk),
        .reset(tb_reset),
        .rx(tb_rx),
        .s_tick(tb_s_tick),
        .rx_done(tb_rx_done),
        .parity_error(tb_parity_error),
        .rx_data(tb_rx_data)
    );

    // 4. Generate the Master System Clock Heartbeat (1 MHz -> 1000ns Period)
    always begin
        #500 tb_clk = ~tb_clk; // Toggle every 500ns to yield a 1us clock period
    end

    // Standard local time representation for 1 Baud duration at 9600 Baud
    // 1 / 9600 seconds = ~104,166 nanoseconds
    localparam BAUD_PERIOD = 104166;

    // 5. Test Stimulus Task (Automates feeding a frame onto the serial wire)
    task send_uart_frame;
        input [7:0] test_byte;
        integer i;
        reg calc_even_parity;
        begin
            // Calculate Even Parity bit locally within the task loop
            calc_even_parity = ^test_byte; 
            
            $display("[TX SIM] Sending Byte: 0x%h (Binary: %b)", test_byte, test_byte);
            
            // A. Start Bit (Pull line LOW)
            tb_rx = 1'b0;
            #BAUD_PERIOD;
            
            // B. Data Bits (LSB-first sequence)
            for (i = 0; i < 8; i = i + 1) begin
                tb_rx = test_byte[i];
                #BAUD_PERIOD;
            end
            
            // C. Send Parity Bit
            tb_rx = calc_even_parity;
            #BAUD_PERIOD;
            
            // D. Stop Bit (Drive line back HIGH)
            tb_rx = 1'b1;
            #BAUD_PERIOD;
            
            $display("[TX SIM] Finished transmitting frame.");
        end
    endtask

    //  task to intentionally inject a corrupted parity bit frame
    task send_corrupted_frame;
        input [7:0] test_byte;
        integer i;
        begin
            $display("[TX SIM WARNING] Injecting Corrupted Frame with bad parity bit!");
            // Start Bit
            tb_rx = 1'b0; #BAUD_PERIOD;
            // Data Bits
            for (i = 0; i < 8; i = i + 1) begin
                tb_rx = test_byte[i]; #BAUD_PERIOD;
            end
            // Inject WRONG parity bit intentionally (Inverting correct even parity)
            tb_rx = ~(^test_byte); 
            #BAUD_PERIOD;
            // Stop Bit
            tb_rx = 1'b1; #BAUD_PERIOD;
        end
    endtask

    // 6. Chronological Test Stimulus Execution
    // 6. Chronological Test Stimulus Execution
    initial begin
        // Setup local waveform tracking dump files for GTKWave
        $dumpfile("waveform.vcd");
        $dumpvars(0, uart_rx_tb);
        
        // Initial conditions
        tb_clk   = 0;
        tb_reset = 1;
        tb_rx    = 1; // Line rests at logic HIGH
        #2000;
        
        // Release reset line
        tb_reset = 0;
        #5000;
        
        // --- TEST CASE 1: Target alternating pattern 8'b10101010 (8'hAA) ---
        // Expected behavior: rx_data outputs 8'hAA, rx_done pulses, parity_error stays 0
        send_uart_frame(8'hAA); 
        #50000; // Hold gap window between frames
        
        // --- TEST CASE 2: Send a corrupted data frame to verify parity error flags ---
        // Expected behavior: rx_done pulses, parity_error asserts HIGH to catch corruption
        send_corrupted_frame(8'hAA); 
        #50000;

        $display("[SIM COMPLETE] Shutting down testing rig.");
        $finish;
    end
endmodule
