module axi_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input clk,
    input rst,

    // WRITE ADDRESS CHANNEL
    output reg [ID_WIDTH-1:0] AWID,
    output reg [ADDR_WIDTH-1:0] AWADDR,
    output reg [7:0] AWLEN,
    output reg [2:0] AWSIZE,
    output reg [1:0] AWBURST,
    output reg [2:0] AWPROT,
    output reg [3:0] AWCACHE,
    output reg [3:0] AWQOS,
    output reg AWVALID,
    input  AWREADY,

    // WRITE DATA CHANNEL
    output reg [DATA_WIDTH-1:0] WDATA,
    output reg WVALID,
    input  WREADY,
    output reg WLAST,

    // WRITE RESPONSE CHANNEL
    input  [1:0] BRESP,
    input  BVALID,
    output reg BREADY,

    // READ ADDRESS CHANNEL
    output reg [ID_WIDTH-1:0] ARID,
    output reg [ADDR_WIDTH-1:0] ARADDR,
    output reg [7:0] ARLEN,
    output reg [2:0] ARSIZE,
    output reg [1:0] ARBURST,
    output reg [2:0] ARPROT,
    output reg [3:0] ARCACHE,
    output reg [3:0] ARQOS,
    output reg ARVALID,
    input  ARREADY,

    // READ DATA CHANNEL
    input  [DATA_WIDTH-1:0] RDATA,
    input  RVALID,
    input  RLAST,
    output reg RREADY
);

// STATES

localparam IDLE       = 0;
localparam READ_ADDR  = 1;
localparam READ_DATA  = 2;
localparam WRITE_ADDR = 3;
localparam WRITE_DATA = 4;
localparam WRITE_RESP = 5;

reg [2:0] state;

// INTERNAL REGISTERS


reg [7:0] beat_cnt;

reg [DATA_WIDTH-1:0] buffer [0:15];

reg [ADDR_WIDTH-1:0] read_addr;
reg [ADDR_WIDTH-1:0] write_addr;

// FSM

always @(posedge clk) begin

if(rst) begin

    state   <= IDLE;

    AWVALID <= 0;
    ARVALID <= 0;
    WVALID  <= 0;
    RREADY  <= 0;
    BREADY  <= 0;

end

else begin

case(state
// IDLE STATE

IDLE: begin

    beat_cnt <= 0;

    read_addr  <= 32'h00001000;
    write_addr <= 32'h00002000;

    // READ CHANNEL CONFIGURATION
    ARID    <= 0;
    ARADDR  <= read_addr;
    ARLEN   <= 8'd3;       // 4 beats
    ARSIZE  <= 3'd2;       // 4 bytes per beat
    ARBURST <= 2'b01;      // INCR burst
    ARPROT  <= 3'b000;
    ARCACHE <= 4'b0011;
    ARQOS   <= 4'b0000;

    state <= READ_ADDR;

end

// SEND READ ADDRESS

READ_ADDR: begin

    ARVALID <= 1;

    if(ARVALID && ARREADY) begin
        ARVALID <= 0;
        RREADY  <= 1;
        state   <= READ_DATA;
    end

end


// RECEIVE READ DATA

READ_DATA: begin

    if(RVALID && RREADY) begin

        // store data in buffer
        buffer[beat_cnt] <= RDATA;

        beat_cnt <= beat_cnt + 1;

        if(RLAST) begin

            RREADY <= 0;
            beat_cnt <= 0;

            // WRITE CHANNEL CONFIGURATION
            AWID    <= ARID;
            AWADDR  <= write_addr;
            AWLEN   <= ARLEN;
            AWSIZE  <= ARSIZE;
            AWBURST <= ARBURST;
            AWPROT  <= 3'b000;
            AWCACHE <= 4'b0011;
            AWQOS   <= 4'b0000;

            state <= WRITE_ADDR;

        end

    end

end

// SEND WRITE ADDRESS

WRITE_ADDR: begin

    AWVALID <= 1;

    if(AWVALID && AWREADY) begin
        AWVALID <= 0;
        state <= WRITE_DATA;
    end

end

// WRITE DATA


WRITE_DATA: begin

    WVALID <= 1;

    if(WVALID && WREADY) begin

        // send buffered data
        WDATA <= buffer[beat_cnt];

        // generate last signal
        WLAST <= (beat_cnt == AWLEN);

        beat_cnt <= beat_cnt + 1;

        if(WLAST) begin
            WVALID <= 0;
            BREADY <= 1;
            state  <= WRITE_RESP;
        end

    end

end

// WRITE RESPONSE


WRITE_RESP: begin

    if(BVALID && BREADY) begin
        BREADY <= 0;
        state  <= IDLE;
    end

end

endcase

end
end

endmodule
