
// UART Transmitter
//   PARITY_EN   - 0 = no parity, 1 = parity enabled
//   PARITY_TYPE - 0 = even parity, 1 = odd parity


module uart_tx #(
    parameter CLK_FREQ    = 50_000_000,
    parameter BAUD_RATE   = 115_200,
    parameter PARITY_EN   = 1,   // 0=none, 1=enabled
    parameter PARITY_TYPE = 0    // 0=even, 1=odd
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    localparam IDLE   = 3'd0;
    localparam START  = 3'd1;
    localparam DATA   = 3'd2;
    localparam PARITY = 3'd3;
    localparam STOP   = 3'd4;

    reg [2:0]                state;
    reg [$clog2(BAUD_DIV):0] baud_cnt;
    reg [2:0]                bit_idx;
    reg [7:0]                shift_reg;
    reg                      parity_bit;

    wire baud_tick = (baud_cnt == BAUD_DIV - 1);

    // Compute parity bit from latched data
    // Even parity: XOR of all data bits should equal 0
    // Odd  parity: XOR of all data bits should equal 1
    // ^tx_data = reduction XOR (1 if odd number of 1s in data)
    // PARITY_TYPE = 0 (even): parity_bit = ^tx_data  (make total 1s even)
    // PARITY_TYPE = 1 (odd):  parity_bit = ~^tx_data (make total 1s odd)
    wire parity_calc = ^tx_data ^ PARITY_TYPE;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            tx         <= 1'b1;
            tx_busy    <= 1'b0;
            tx_done    <= 1'b0;
            baud_cnt   <= 0;
            bit_idx    <= 0;
            shift_reg  <= 0;
            parity_bit <= 0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                // IDLE
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg  <= tx_data;
                        parity_bit <= parity_calc;
                        baud_cnt   <= 0;
                        bit_idx    <= 0;
                        tx_busy    <= 1'b1;
                        state      <= START;
                    end
                end

                //  START BIT 
                START: begin
                    tx <= 1'b0;
                    if (baud_tick) begin
                        baud_cnt <= 0;
                        state    <= DATA;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                //  DATA BITS (LSB first) 
                DATA: begin
                    tx <= shift_reg[0];
                    if (baud_tick) begin
                        baud_cnt  <= 0;
                        shift_reg <= shift_reg >> 1;
                        if (bit_idx == 3'd7) begin
                            state <= (PARITY_EN) ? PARITY : STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                //  PARITY BIT 
                PARITY: begin
                    tx <= parity_bit;
                    if (baud_tick) begin
                        baud_cnt <= 0;
                        state    <= STOP;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                //  STOP BIT 
                STOP: begin
                    tx <= 1'b1;
                    if (baud_tick) begin
                        baud_cnt <= 0;
                        tx_done  <= 1'b1;
                        state    <= IDLE;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
