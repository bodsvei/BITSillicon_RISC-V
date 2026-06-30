module id_stage (
    input  wire        clk,
    input  wire        rst,
    
    // From IF/ID register
    input  wire [31:0] ifid_pc,
    input  wire [31:0] ifid_pc_plus4,
    input  wire [31:0] ifid_instr,
    
    // From Register File (Abhimanyu's module)
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

    // Instantiate Control Unit (Anirudh's module)
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
        .auipc      (idex_auipc)
    );

    // -------------------------------------------------------------------------
    // Inter-module wiring and Pipeline Pass-throughs
    // -------------------------------------------------------------------------
    
    // Pass rs1 and rs2 addresses to Register File
    assign rf_rs1_addr = rs1;
    assign rf_rs2_addr = rs2;

    // Pass data directly to ID/EX register
    assign idex_pc       = ifid_pc;
    assign idex_pc_plus4 = ifid_pc_plus4;
    assign idex_imm      = imm;
    assign idex_rs1_addr = rs1;
    assign idex_rs2_addr = rs2;
    assign idex_rd_addr  = rd;
    assign idex_funct3   = funct3;

    // -------------------------------------------------------------------------
    // Microarchitectural Tweak: AUIPC Support
    // -------------------------------------------------------------------------
    // AUIPC (0010111) computes rd = PC + imm using the ALU.
    // The standard forwarding paths only allow rs1_data into ALU Operand A.
    // By detecting AUIPC here and multiplexing `ifid_pc` into `idex_rs1_data`,
    // the ALU will receive the PC in the EX stage and add it to the immediate.
    // This is safe because `instr_decoder` already sets `rs1 = 0` for AUIPC,
    // so the hazard unit will not forward any EX or MEM values over this PC value.
    // Uses the control_unit's `auipc` output rather than raw opcode matching.
    assign idex_rs1_data = idex_auipc ? ifid_pc : rf_rdata1;
    assign idex_rs2_data = rf_rdata2;

endmodule
