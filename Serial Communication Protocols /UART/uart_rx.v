
// UART Receiver 

//   PARITY_EN   - 0 = no parity, 1 = parity enabled
//   PARITY_TYPE - 0 = even parity, 1 = odd parity

//   rx_parity_err- Pulses HIGH if parity mismatch detected
//   rx_frame_err - Pulses HIGH if stop bit is missing
// ============================================================

module uart_rx #(
    parameter CLK_FREQ    = 50_000_000,
    parameter BAUD_RATE   = 115_200,
    parameter PARITY_EN   = 1,   // 0=none, 1=enabled
    parameter PARITY_TYPE = 0    // 0=even, 1=odd
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_done,
    output reg        rx_parity_err,
    output reg        rx_frame_err
);

    localparam BAUD_DIV      = CLK_FREQ / BAUD_RATE;
    localparam HALF_BAUD_DIV = BAUD_DIV / 2;

    localparam IDLE   = 3'd0;
    localparam START  = 3'd1;
    localparam DATA   = 3'd2;
    localparam PARITY = 3'd3;
    localparam STOP   = 3'd4;

    reg [2:0]                state;
    reg [$clog2(BAUD_DIV):0] baud_cnt;
    reg [2:0]                bit_idx;
    reg [7:0]                shift_reg;
    reg                      parity_acc; // Accumulated parity over received bits

    // 2-FF synchronizer
    reg rx_sync0, rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync  <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync  <= rx_sync0;
        end
    end

    wire baud_tick      = (baud_cnt == BAUD_DIV - 1);
    wire half_baud_tick = (baud_cnt == HALF_BAUD_DIV - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            baud_cnt       <= 0;
            bit_idx        <= 0;
            shift_reg      <= 0;
            parity_acc     <= 0;
            rx_data        <= 0;
            rx_done        <= 1'b0;
            rx_parity_err  <= 1'b0;
            rx_frame_err   <= 1'b0;
        end else begin
            rx_done       <= 1'b0;
            rx_parity_err <= 1'b0;
            rx_frame_err  <= 1'b0;

            case (state)
                //  IDLE
                IDLE: begin
                    if (!rx_sync) begin   // Falling edge = start bit
                        baud_cnt   <= 0;
                        parity_acc <= PARITY_TYPE;  // Seed: 0=even, 1=odd
                        state      <= START;
                    end
                end

                //  START BIT 
                // Sample at half-baud to confirm it's a real start bit
                START: begin
                    if (half_baud_tick) begin
                        if (!rx_sync) begin
                            baud_cnt <= 0;
                            bit_idx  <= 0;
                            state    <= DATA;
                        end else begin
                            state <= IDLE;  // Glitch — abort
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                //  DATA BITS (LSB first) 
                DATA: begin
                    if (baud_tick) begin
                        baud_cnt   <= 0;
                        shift_reg  <= {rx_sync, shift_reg[7:1]};
                        parity_acc <= parity_acc ^ rx_sync; // Running XOR
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
                // After all 8 data bits, parity_acc XOR'd with received
                // parity bit should equal 0 for a valid frame.
                PARITY: begin
                    if (baud_tick) begin
                        baud_cnt <= 0;
                        // parity_acc was seeded with PARITY_TYPE and XOR'd
                        // with each data bit. XOR with the received parity
                        // bit should yield 0 if no error.
                        if (parity_acc ^ rx_sync != 1'b0)
                            rx_parity_err <= 1'b1;
                        state <= STOP;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                //  STOP BIT 
                STOP: begin
                    if (baud_tick) begin
                        baud_cnt <= 0;
                        if (rx_sync) begin
                            rx_data <= shift_reg;
                            rx_done <= 1'b1;
                        end else begin
                            rx_frame_err <= 1'b1;  // Missing stop bit
                        end
                        state <= IDLE;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
