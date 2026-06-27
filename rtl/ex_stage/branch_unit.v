module branch_unit (
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [31:0] pc,
    input  wire [31:0] pc_plus4,
    input  wire [31:0] imm,
    input  wire [2:0]  funct3,
    input  wire        branch,
    input  wire        jump,
    input  wire        alu_src,   // 1 = JALR (rs1+imm), 0 = JAL (pc+imm)
    output reg         branch_taken,
    output reg  [31:0] branch_target
);
    wire signed_lt  = ($signed(rs1_data) < $signed(rs2_data));
    wire unsigned_lt = (rs1_data < rs2_data);
    wire eq          = (rs1_data == rs2_data);

    reg cond;
    always @(*) begin
        case (funct3)
            3'b000: cond = eq;           // BEQ
            3'b001: cond = !eq;          // BNE
            3'b100: cond = signed_lt;    // BLT
            3'b101: cond = !signed_lt;   // BGE
            3'b110: cond = unsigned_lt;  // BLTU
            3'b111: cond = !unsigned_lt; // BGEU
            default: cond = 1'b0;
        endcase
    end

    wire [31:0] jalr_target = rs1_data + imm;

    always @(*) begin
        if (jump) begin
            branch_taken  = 1'b1;
            if (alu_src)
                branch_target = {jalr_target[31:1], 1'b0}; // JALR: rs1+imm, lsb=0
            else
                branch_target = pc + imm;                    // JAL: pc+imm
        end else if (branch && cond) begin
            branch_taken  = 1'b1;
            branch_target = pc + imm;
        end else begin
            branch_taken  = 1'b0;
            branch_target = pc_plus4;
        end
    end

endmodule
