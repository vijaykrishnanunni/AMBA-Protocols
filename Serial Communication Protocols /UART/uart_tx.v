
// UART Transmitter


module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
);

    // Baud rate tick counter limit
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    // FSM states
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0]                state;
    reg [$clog2(BAUD_DIV):0] baud_cnt;   // Baud rate counter
    reg [2:0]                bit_idx;    // Current data bit index
    reg [7:0]                shift_reg;  // Data shift register

    // Baud tick signal
    wire baud_tick = (baud_cnt == BAUD_DIV - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            tx       <= 1'b1;   // Idle HIGH
            tx_busy  <= 1'b0;
            tx_done  <= 1'b0;
            baud_cnt <= 0;
            bit_idx  <= 0;
            shift_reg<= 0;
        end else begin
            tx_done <= 1'b0;    // Default: not done

            case (state)
                // ---- IDLE ----------------------------------------
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        baud_cnt  <= 0;
                        bit_idx   <= 0;
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end

                // ---- START BIT -----------------------------------
                START: begin
                    tx <= 1'b0;     // START bit is LOW
                    if (baud_tick) begin
                        baud_cnt <= 0;
                        state    <= DATA;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                // ---- DATA BITS (LSB first) -----------------------
                DATA: begin
                    tx <= shift_reg[0];
                    if (baud_tick) begin
                        baud_cnt  <= 0;
                        shift_reg <= shift_reg >> 1;
                        if (bit_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                // ---- STOP BIT ------------------------------------
                STOP: begin
                    tx <= 1'b1;     // STOP bit is HIGH
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
