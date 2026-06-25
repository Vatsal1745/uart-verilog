`timescale 1ns/1ps

module baud_gen_tb;

//1.fake wires
reg tb_clk;
reg tb_reset;
wire tb_tick;

//2.plug in module
baud_gen #(
    .clk_freq(1000000),
    .baud_rate(9600),
    .oversample(1)
) uut (
    .clk(tb_clk),
    .reset(tb_reset),
    .baud_tick(tb_tick)
);

//3.clock generator
always begin 
    #5 tb_clk = ~ tb_clk;
end

// 4. Test stimulus
initial begin 
    $dumpfile("waveform.vcd");
    $dumpvars(0, baud_gen_tb);

    tb_clk = 0;
    tb_reset = 1;
    #20;
    tb_reset = 0;
    #50000; 
    
    $dumpoff; // Tells the compiler to stop recording data
    #10;      // Gives the system a 10ns breathing room to flush data to disk
    $finish;
end
endmodule



