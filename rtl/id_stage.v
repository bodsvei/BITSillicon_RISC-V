// =============================================================================
// id_stage.v — Instruction Decode Stage (Standalone Wrapper)
//
// NOTE: riscv_top.v inlines all of the ID logic directly. This standalone
//       wrapper is kept for integration/unit testing but is NOT used in top.
//
// Instantiates:
//   instr_decoder : slices instruction fields
//   imm_gen       : extracts and sign-extends immediate
//   control_unit  : produces all datapath control signals
//
// AUIPC note:
//   The AUIPC PC injection (rd = PC + U-imm) is handled in riscv_top.v by
//   overriding ALU operand A in the EX stage when idex_auipc is set:
//     alu_operand_a = idex_auipc ? idex_pc : fwd_src_a
//   This module simply passes rf_rdata1 through to idex_rs1_data without
//   any AUIPC override, because the EX-stage override is the authoritative
//   mechanism.
// =============================================================================

module id_stage (
    input  wire        clk,
    input  wire        rst,

    // From IF/ID register
    input  wire [31:0] ifid_pc,
    input  wire [31:0] ifid_pc_plus4,
    input  wire [31:0] ifid_instr,

    // From Register File
    input  wire [31:0] rf_rdata1,
    input  wire [31:0] rf_rdata2,

    // Outputs to Register File
    output wire [4:0]  rf_rs1_addr,
    output wire [4:0]  rf_rs2_addr,

    // Outputs to ID/EX register
    output wire [31:0] idex_pc,
    output wire [31:0] idex_pc_plus4,
    output wire [31:0] idex_rs1_data,
    output wire [31:0] idex_rs2_data,
    output wire [31:0] idex_imm,
    output wire [4:0]  idex_rs1_addr,
    output wire [4:0]  idex_rs2_addr,
    output wire [4:0]  idex_rd_addr,
    output wire [3:0]  idex_alu_op,
    output wire        idex_alu_src,
    output wire        idex_reg_write,
    output wire        idex_mem_read,
    output wire        idex_mem_write,
    output wire [1:0]  idex_mem_to_reg,
    output wire        idex_branch,
    output wire        idex_jump,
    output wire [2:0]  idex_funct3,
    output wire        idex_auipc
);

    // Internal wires from instruction decoder
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [31:0] imm;
    wire        trap_unused;   // trap signal available but not used here
    wire [2:0]  imm_src_unused; // imm_src available; imm_gen re-derives it from opcode

    // Instantiate Instruction Decoder
    instr_decoder u_instr_decoder (
        .instr  (ifid_instr),
        .opcode (opcode),
        .funct3 (funct3),
        .funct7 (funct7),
        .rs1    (rs1),
        .rs2    (rs2),
        .rd     (rd)
    );

    // Instantiate Immediate Generator
    imm_gen u_imm_gen (
        .instr (ifid_instr),
        .imm   (imm)
    );

    // Instantiate Control Unit
    control_unit u_control_unit (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .alu_op     (idex_alu_op),
        .alu_src    (idex_alu_src),
        .reg_write  (idex_reg_write),
        .mem_read   (idex_mem_read),
        .mem_write  (idex_mem_write),
        .mem_to_reg (idex_mem_to_reg),
        .branch     (idex_branch),
        .jump       (idex_jump),
        .trap       (trap_unused),
        .auipc      (idex_auipc),
        .imm_src    (imm_src_unused)
    );

    // -------------------------------------------------------------------------
    // Inter-module wiring and pipeline pass-throughs
    // -------------------------------------------------------------------------

    // Register file address outputs
    assign rf_rs1_addr = rs1;
    assign rf_rs2_addr = rs2;

    // Pass data to ID/EX register
    assign idex_pc       = ifid_pc;
    assign idex_pc_plus4 = ifid_pc_plus4;
    assign idex_imm      = imm;
    assign idex_rs1_addr = rs1;
    assign idex_rs2_addr = rs2;
    assign idex_rd_addr  = rd;
    assign idex_funct3   = funct3;

    // Register file data pass-through — no AUIPC override here.
    // The EX stage (riscv_top.v) overrides ALU operand A for AUIPC.
    assign idex_rs1_data = rf_rdata1;
    assign idex_rs2_data = rf_rdata2;

endmodule
