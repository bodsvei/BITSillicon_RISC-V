module reg_file (
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] wdata,
    input  wire        reg_write
);
    reg [31:0] regs [1:31];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 1; i < 32; i = i + 1)
                regs[i] <= 32'h0;
        end else if (reg_write && rd_addr != 5'h0) begin
            regs[rd_addr] <= wdata;
        end
    end

    // x0 hardwired to 0; write-then-read forwarding on address collision
    assign rdata1 = (rs1_addr == 5'h0) ? 32'h0 :
                    (reg_write && rd_addr == rs1_addr) ? wdata :
                    regs[rs1_addr];

    assign rdata2 = (rs2_addr == 5'h0) ? 32'h0 :
                    (reg_write && rd_addr == rs2_addr) ? wdata :
                    regs[rs2_addr];

endmodule
