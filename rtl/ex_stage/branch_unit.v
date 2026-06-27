// ============================================================
// Module      : branch_unit
// File        : rtl/ex_stage/branch_unit.v
// Project     : BITSilicon RV32I 5-Stage Pipelined RISC-V Processor
// Contributor : Aparna
// ============================================================
//
// Description:
//   Handles all branch and jump decisions in the EX stage.
//   Answers two questions every time a branch/jump is encountered:
//     1. Should we jump?      → output: PCSrc (0 or 1)
//     2. Where do we jump to? → output: PCTarget (32-bit address)
//
// Instructions handled:
//   BEQ, BNE, BLT, BGE, BLTU, BGEU  (conditional branches)
//   JAL                               (unconditional jump, PC-relative)
//   JALR                              (unconditional jump, register-relative)
//
// How it works:
//   - reads funct3 to identify which branch type it is
//   - reads ALU flags (N, Z, C, V) to evaluate the condition
//   - computes correct target address based on instruction type
//   - sends PCSrc + PCTarget back to IF stage
//
// Position in pipeline:
//   IF → ID → EX (here) → MEM → WB
// ============================================================

module branch_unit (
    input wire        Branch,
    input wire        Jump,
    input wire        is_jalr,
    input wire [2:0]  funct3,
    input wire [3:0]  ALUFlags,
    input wire [31:0] PC,
    input wire [31:0] rs1,
    input wire [31:0] B_imm,
    input wire [31:0] J_imm,
    input wire [31:0] I_imm,
    output reg        PCSrc,
    output reg [31:0] PCTarget
);

    wire N = ALUFlags[3];
    wire Z = ALUFlags[2];
    wire C = ALUFlags[1];
    wire V = ALUFlags[0];

    reg BranchTaken;

    always @(*) begin
        case (funct3)
            3'b000: BranchTaken = Z;
            3'b001: BranchTaken = ~Z;
            3'b100: BranchTaken = N ^ V;
            3'b101: BranchTaken = ~(N ^ V);
            3'b110: BranchTaken = ~C;
            3'b111: BranchTaken = C;
            default: BranchTaken = 1'b0;
        endcase
    end

    always @(*) begin
        PCSrc = (Branch & BranchTaken) | Jump;
    end

    always @(*) begin
        if (is_jalr)
            PCTarget = (rs1 + I_imm) & 32'hFFFFFFFE;
        else if (Jump)
            PCTarget = PC + J_imm;
        else
            PCTarget = PC + B_imm;
    end

endmodule