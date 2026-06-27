// Wrapper combining main_decoder and alu_decoder into control_unit
// as instantiated by riscv_top.v
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output wire [3:0] alu_op,
    output wire       alu_src,
    output wire       reg_write,
    output wire       mem_read,
    output wire       mem_write,
    output wire [1:0] mem_to_reg,
    output wire       branch,
    output wire       jump,
    output wire       auipc   // 1 for AUIPC: EX must use PC as ALU operand_a
);
    wire [2:0] imm_src_unused;

    main_decoder MDEC (
        .opcode    (opcode),
        .RegWrite  (reg_write),
        .ALUSrc    (alu_src),
        .MemRead   (mem_read),
        .MemWrite  (mem_write),
        .Branch    (branch),
        .Jump      (jump),
        .ResultSrc (mem_to_reg),
        .ImmSrc    (imm_src_unused),
        .AuiPC     (auipc)
    );

    alu_decoder ADEC (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7b5   (funct7[5]),
        .ALUControl (alu_op)
    );

endmodule
