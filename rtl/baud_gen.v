module baud_gen # (
    //hash#(parameter list) is used to write reusable hardware code
    parameter clk_freq = 50000000,
    parameter baud_rate = 9600,
    parameter oversample = 1 // pass 16 for Rx
)(
    input clk,
    input reset,
    output baud_tick
);
//logic
localparam divisor = clk_freq/(baud_rate * oversample); //5208
reg[12:0] counter;

//always block
always @ (posedge clk or posedge reset) begin
    if(reset) begin
        counter <= 13'd0;
    end else begin
        if(counter == (divisor -1)) begin 
            counter <= 13'd0; // baud_tick
        end else begin 
            counter <= counter + 1'b1;
        end
    end
end
 
assign baud_tick = (counter == (divisor -1))? 1'b1 : 1'b0;
endmodule

