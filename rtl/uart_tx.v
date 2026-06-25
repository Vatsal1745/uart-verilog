module uart_tx(
    input  wire       clk,
    input  wire        rst,
    input  wire        baud_tick,
    input  wire        tx_start,
    input  wire [7:0]  data_in,
    output reg         tx_out,
    output reg         tx_busy
);

    localparam IDLE   = 3'd0;
    localparam START  = 3'd1;
    localparam DATA   = 3'd2;
    localparam PARITY = 3'd3;
    localparam STOP   = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg       parity_bit;

    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    if (tx_start) next_state = START;
            START:   if (baud_tick) next_state = DATA;
            DATA:    if (baud_tick && bit_cnt == 3'd7) next_state = PARITY;
            PARITY:  if (baud_tick) next_state = STOP;
            STOP:    if (baud_tick) next_state = IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_out     <= 1'b1;
            tx_busy    <= 1'b0;
            shift_reg  <= 8'd0;
            bit_cnt    <= 3'd0;
            parity_bit <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out <= 1'b1;
                    if (tx_start) begin
                        shift_reg  <= data_in;
                        parity_bit <= ^data_in;
                        tx_busy    <= 1'b1;
                        bit_cnt    <= 3'd0;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                START: begin
                    tx_out <= 1'b0;
                end

                DATA: begin
                    tx_out <= shift_reg[0];
                    if (baud_tick) begin
                        shift_reg <= shift_reg >> 1;
                        bit_cnt   <= bit_cnt + 1'b1;
                    end
                end

                PARITY: begin
                    tx_out <= parity_bit;
                end

                STOP: begin
                    tx_out <= 1'b1;
                    if (baud_tick)
                        tx_busy <= 1'b0;
                end
            endcase
        end
    end

endmodule