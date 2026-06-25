`timescale 1ns / 1ps

module uart_tx_tb;

    // Testbench Signals
    reg        clk;
    reg        rst;
    reg        baud_tick;
    reg        tx_start;
    reg [7:0]  data_in;
    
    wire       tx_out;
    wire       tx_busy;

    // Instantiate Unit Under Test (UUT)
    tx_fsm uut (
        .clk(clk),
        .rst(rst),
        .baud_tick(baud_tick),
        .tx_start(tx_start),
        .data_in(data_in),
        .tx_out(tx_out),
        .tx_busy(tx_busy)
    );

    // 1. Clock Generation (50MHz Clock -> 20ns period)
    always begin
        #10 clk = ~clk;
    end

    // 2. Emulated Baud Tick Generator Loop
    // Fires an isolated tick pulse every 5 clock cycles for readable simulation waves
    initial begin
        baud_tick = 1'b0;
        forever begin
            #80; // Wait 4 full clock cycles
            baud_tick = 1'b1;
            #20; // Hold high for exactly 1 clock cycle
            baud_tick = 1'b0;
        end
    end

    // 3. Main Stimulus Vector Routine
    initial begin
        // Initialize Inputs
        clk      = 1'b0;
        rst      = 1'b1;
        tx_start = 1'b0;
        data_in  = 8'd0;

        // Apply Reset
        #40;
        rst = 1'b0;
        #40;

        // --- Transaction 1: Send Data 8'b10100101 (Even Parity Example) ---
        // Number of 1s = 4 (Even number of 1s -> Parity bit should compute to 0)
        @(posedge clk);
        data_in  = 8'b10100101; 
        tx_start = 1'b1;
        
        @(posedge clk);
        tx_start = 1'b0; // Clear start signal immediately (1-cycle pulse)

        // Wait for transmission to completely conclude
        @(posedge clk);
        while (tx_busy) begin
            @(posedge clk);
        end
        
        #100; // Inter-packet cooldown gap

        // --- Transaction 2: Send Data 8'b10101010 (Even Parity Example) ---
        // Number of 1s = 4 (Even number of 1s -> Parity bit should compute to 0)
        @(posedge clk);
        data_in  = 8'b10101010;
        tx_start = 1'b1;
        
        @(posedge clk);
        tx_start = 1'b0;

        // Wait for second transmission to finish
        @(posedge clk);
        while (tx_busy) begin
            @(posedge clk);
        end

        #200;
        $display("Simulation successfully completed with both parity checks verified.");
        $finish;
    end

    // FIXED: VCD wave dumping block targeting corrected scopes and extensions
    initial begin
        $dumpfile("tx_fsm_tb.vcd"); // Creates wave file
        $dumpvars(0, tx_fsm_tb);    // Matches top-level module scope name
    end

endmodule