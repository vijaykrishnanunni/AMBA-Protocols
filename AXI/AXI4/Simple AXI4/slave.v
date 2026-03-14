module axi_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter MEM_DEPTH  = 1024
)(
    input clk,
    input rst,

    // WRITE ADDRESS CHANNEL
    input  [ID_WIDTH-1:0] AWID,
    input  [ADDR_WIDTH-1:0] AWADDR,
    input  [7:0] AWLEN,
    input  [2:0] AWSIZE,
    input  [1:0] AWBURST,
    input  [2:0] AWPROT,
    input  [3:0] AWCACHE,
    input  [3:0] AWQOS,
    input  AWVALID,
    output reg AWREADY,

    // WRITE DATA CHANNEL
    input  [DATA_WIDTH-1:0] WDATA,
    input  WVALID,
    output reg WREADY,
    input  WLAST,

    // WRITE RESPONSE CHANNEL
    output reg [ID_WIDTH-1:0] BID,
    output reg [1:0] BRESP,
    output reg BVALID,
    input  BREADY,

    // READ ADDRESS CHANNEL
    input  [ID_WIDTH-1:0] ARID,
    input  [ADDR_WIDTH-1:0] ARADDR,
    input  [7:0] ARLEN,
    input  [2:0] ARSIZE,
    input  [1:0] ARBURST,
    input  [2:0] ARPROT,
    input  [3:0] ARCACHE,
    input  [3:0] ARQOS,
    input  ARVALID,
    output reg ARREADY,

    // READ DATA CHANNEL
    output reg [ID_WIDTH-1:0] RID,
    output reg [DATA_WIDTH-1:0] RDATA,
    output reg [1:0] RRESP,
    output reg RVALID,
    output reg RLAST,
    input  RREADY
);

// MEMORY
reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

// INTERNAL REGISTERS

reg [ADDR_WIDTH-1:0] write_addr;
reg [ADDR_WIDTH-1:0] read_addr;

reg [7:0] write_cnt;
reg [7:0] read_cnt;

reg [ID_WIDTH-1:0] write_id;
reg [ID_WIDTH-1:0] read_id;

// WRITE LOGIC

always @(posedge clk) begin

if(rst) begin
    AWREADY <= 0;
    WREADY  <= 0;
    BVALID  <= 0;
end

else begin

    // accept write address
    if(AWVALID && !AWREADY) begin
        AWREADY <= 1;

        write_addr <= AWADDR >> 2;
        write_cnt  <= 0;

        write_id <= AWID;   // store transaction ID
    end
    else
        AWREADY <= 0;

    // accept write data
    if(WVALID && !WREADY) begin

        WREADY <= 1;

        mem[write_addr + write_cnt] <= WDATA;

        write_cnt <= write_cnt + 1;

        if(WLAST) begin
            BID   <= write_id;   // return same ID
            BRESP <= 2'b00;      // OKAY
            BVALID <= 1;
        end
    end
    else
        WREADY <= 0;

    // write response handshake
    if(BVALID && BREADY)
        BVALID <= 0;

end

end

// READ LOGIC

always @(posedge clk) begin

if(rst) begin
    ARREADY <= 0;
    RVALID  <= 0;
end

else begin

    // accept read address
    if(ARVALID && !ARREADY) begin
        ARREADY <= 1;

        read_addr <= ARADDR >> 2;
        read_cnt  <= 0;

        read_id <= ARID;   // store transaction ID
    end
    else
        ARREADY <= 0;

    // send read data
    if(!RVALID || (RVALID && RREADY)) begin

        RID   <= read_id;
        RDATA <= mem[read_addr + read_cnt];
        RRESP <= 2'b00; // OKAY

        RVALID <= 1;

        RLAST <= (read_cnt == ARLEN);

        read_cnt <= read_cnt + 1;

        if(RLAST)
            RVALID <= 0;

    end

end

end

endmodule
