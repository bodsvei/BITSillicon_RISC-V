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
//     1. Should we jump?      → output: branch_taken (0 or 1)
//     2. Where do we jump to? → output: branch_target (32-bit address)
//
// Instructions handled:
//   BEQ, BNE, BLT, BGE, BLTU, BGEU  (conditional branches)
//   JAL                               (unconditional, PC-relative)
//   JALR                              (unconditional, register-relative)
//
// JALR identification:
//   jump=1 and alu_src=1 → JALR (operand B is immediate)
//   jump=1 and alu_src=0 → JAL  (operand B is register)
//
// Position in pipeline:
//   IF → ID → EX (here) → MEM → WB
// ============================================================

module branch_unit (
    // --- data inputs ---
    input  wire [31:0] rs1_data,      // register 1 value (after forwarding)
    input  wire [31:0] rs2_data,      // register 2 value (after forwarding)
    input  wire [31:0] pc,            // current PC (from ID/EX register)
    input  wire [31:0] pc_plus4,      // PC+4 (for link address)
    input  wire [31:0] imm,           // sign-extended immediate (single)

    // --- control inputs ---
    input  wire [2:0]  funct3,        // branch type selector
    input  wire        branch,        // 1 = this is a branch instruction
    input  wire        jump,          // 1 = this is JAL or JALR
    input  wire        alu_src,       // 1 = JALR (imm), 0 = JAL (reg)

    // --- outputs ---
    output reg         branch_taken,  // 1 = take the branch/jump
    output reg  [31:0] branch_target  // address to jump to
);

    // -------------------------------------------------------
    // step 1: compute branch condition directly from registers
    // -------------------------------------------------------
    reg BranchCond;

    always @(*) begin
        case (funct3)
            3'b000: BranchCond = (rs1_data == rs2_data);              // BEQ
            3'b001: BranchCond = (rs1_data != rs2_data);              // BNE
            3'b100: BranchCond = ($signed(rs1_data) <  $signed(rs2_data)); // BLT
            3'b101: BranchCond = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
            3'b110: BranchCond = (rs1_data <  rs2_data);              // BLTU
            3'b111: BranchCond = (rs1_data >= rs2_data);              // BGEU
            default: BranchCond = 1'b0;
        endcase
    end

    // -------------------------------------------------------
    // step 2: should we actually jump? (branch_taken)
    // -------------------------------------------------------
    always @(*) begin
        branch_taken = (branch & BranchCond) | jump;
    end

    // -------------------------------------------------------
    // step 3: compute target address (branch_target)
    // -------------------------------------------------------
    always @(*) begin
        if (jump && alu_src)
            // JALR: jump to rs1 + imm, clear LSB
            branch_target = (rs1_data + imm) & 32'hFFFFFFFE;
        else if (jump)
            // JAL: jump to PC + imm
            branch_target = pc + imm;
        else
            // Branch: jump to PC + imm
            branch_target = pc + imm;
    end

endmodule