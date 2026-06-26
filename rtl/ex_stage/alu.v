module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire        zero,
    output wire        neg,
    output reg         carry,
    output reg         overflow
);

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b1000;
    localparam ALU_SLL  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1101;
    localparam ALU_OR   = 4'b0110;
    localparam ALU_AND  = 4'b0111;

    wire [32:0] add_result;
    assign add_result = {1'b0, a} + {1'b0, b};

    wire [32:0] sub_result;
    assign sub_result = {1'b0, a} + {1'b0, ~b} + 33'd1;

    always @(*) begin
        result   = 32'd0;
        carry    = 1'b0;
        overflow = 1'b0;

        case (alu_ctrl)
            ALU_ADD: begin
                result   = add_result[31:0];
                carry    = add_result[32];
                overflow = (a[31] == b[31]) && (result[31] != a[31]);
            end

            ALU_SUB: begin
                result   = sub_result[31:0];
                carry    = sub_result[32];
                overflow = (a[31] != b[31]) && (result[31] == b[31]);
            end

            ALU_SLL: begin
                result = a << b[4:0];
            end

            ALU_SLT: begin
                result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            end

            ALU_SLTU: begin
                result = (a < b) ? 32'd1 : 32'd0;
            end

            ALU_XOR: begin
                result = a ^ b;
            end

            ALU_SRL: begin
                result = a >> b[4:0];
            end

            ALU_SRA: begin
                result = $signed(a) >>> b[4:0];
            end

            ALU_OR: begin
                result = a | b;
            end

            ALU_AND: begin
                result = a & b;
            end

            default: begin
                result = a + b;
            end
        endcase
    end

    assign zero = (result == 32'd0);
    assign neg  = result[31];

endmodule
