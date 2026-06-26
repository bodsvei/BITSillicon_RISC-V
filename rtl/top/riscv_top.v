// =============================================================================
// rv32i_top.v — RV32I 5-Stage Pipelined Processor Top-Level
// Authors  : Anirudh
// Version  : 0.1
// Spec ref : rv32i_top_spec.md §4-8
//
// Instantiation order mirrors datapath left-to-right:
//   IF → IF/ID reg → ID → ID/EX reg → EX → EX/MEM reg → MEM → MEM/WB reg → WB
// Hazard/Forwarding unit sits beside ID/EX and drives stall + fwd muxes.
// =============================================================================

module riscv_top (
    input  wire        clk,
    input  wire        rst,
    // Debug / testbench observation ports (spec §4)
    output wire [31:0] tb_pc,
    output wire [31:0] tb_alu_result,
    output wire [31:0] tb_reg_wb_data,
    output wire [4:0]  tb_reg_wb_addr,
    output wire        tb_reg_wb_en
);

// =============================================================================
// 0.  HAZARD / FORWARD CONTROL (declared early; driven by hazard_unit below)
// =============================================================================

    wire        stall;          // Freeze PC + IF/ID; bubble into ID/EX
    wire        flush;          // Squash IF/ID + ID/EX on taken branch
    wire [1:0]  fwd_a_sel;     // Forwarding mux for ALU operand A
    wire [1:0]  fwd_b_sel;     // Forwarding mux for ALU operand B

// =============================================================================
// 1.  IF STAGE
// =============================================================================

    // --- PC logic (lives in top per existing skeleton) ---
    wire [31:0] pcF;
    wire [31:0] pcPlus4F;
    wire [31:0] pcNextF;
    wire        branch_taken;   // From EX (branch_unit)
    wire [31:0] branch_target;  // From EX (branch_unit)

    assign pcPlus4F = pcF + 32'd4;
    assign pcNextF  = branch_taken ? branch_target : pcPlus4F;

    pc_reg PC_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (~stall),
        .pc_next (pcNextF),
        .pc      (pcF)
    );

    // --- Instruction memory (inside if_stage) ---
    wire [31:0] instrF;

    instr_mem IMEM (
        .pc    (pcF),
        .instr (instrF)
    );

// =============================================================================
// 2.  IF/ID PIPELINE REGISTER  (spec §5.1)
// =============================================================================

    reg [31:0] ifid_pc;
    reg [31:0] ifid_pc_plus4;
    reg [31:0] ifid_instr;

    always @(posedge clk) begin
        if (rst || flush) begin
            ifid_pc       <= 32'h0;
            ifid_pc_plus4 <= 32'h0;
            ifid_instr    <= 32'h00000013; // NOP: addi x0, x0, 0
        end else if (!stall) begin
            ifid_pc       <= pcF;
            ifid_pc_plus4 <= pcPlus4F;
            ifid_instr    <= instrF;
        end
        // stall: hold all fields unchanged (implicit — no else branch)
    end

// =============================================================================
// 3.  ID STAGE
// =============================================================================

    // --- Field extraction from instruction ---
    wire [6:0]  opcode  = ifid_instr[6:0];
    wire [2:0]  funct3  = ifid_instr[14:12];
    wire [6:0]  funct7  = ifid_instr[31:25];
    wire [4:0]  rs1_addr_D = ifid_instr[19:15];
    wire [4:0]  rs2_addr_D = ifid_instr[24:20];
    wire [4:0]  rd_addr_D  = ifid_instr[11:7];

    // --- Immediate generator ---
    wire [31:0] immD;

    imm_gen IMM_GEN (
        .instr (ifid_instr),
        .imm   (immD)
    );

    // --- Control unit (spec §6.5) ---
    wire [3:0]  alu_op_D;
    wire        alu_src_D;
    wire        reg_write_D;
    wire        mem_read_D;
    wire        mem_write_D;
    wire [1:0]  mem_to_reg_D;
    wire        branch_D;
    wire        jump_D;

    control_unit CTRL (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .alu_op     (alu_op_D),
        .alu_src    (alu_src_D),
        .reg_write  (reg_write_D),
        .mem_read   (mem_read_D),
        .mem_write  (mem_write_D),
        .mem_to_reg (mem_to_reg_D),
        .branch     (branch_D),
        .jump       (jump_D)
    );

    // --- Register file read (write port driven from WB below) ---
    wire [31:0] rf_rdata1_D;
    wire [31:0] rf_rdata2_D;
    // WB signals declared forward; driven by MEM/WB register section
    wire        wb_reg_write;
    wire [4:0]  wb_rd_addr;
    wire [31:0] wb_wdata;

    reg_file RF (
        .clk       (clk),
        .rst       (rst),
        .rs1_addr  (rs1_addr_D),
        .rs2_addr  (rs2_addr_D),
        .rdata1    (rf_rdata1_D),
        .rdata2    (rf_rdata2_D),
        .rd_addr   (wb_rd_addr),
        .wdata     (wb_wdata),
        .reg_write (wb_reg_write)
    );

// =============================================================================
// 4.  ID/EX PIPELINE REGISTER  (spec §5.2)
// =============================================================================

    reg [31:0] idex_pc;
    reg [31:0] idex_pc_plus4;
    reg [31:0] idex_rs1_data;
    reg [31:0] idex_rs2_data;
    reg [31:0] idex_imm;
    reg [4:0]  idex_rs1_addr;
    reg [4:0]  idex_rs2_addr;
    reg [4:0]  idex_rd_addr;
    reg [3:0]  idex_alu_op;
    reg        idex_alu_src;
    reg        idex_reg_write;
    reg        idex_mem_read;
    reg        idex_mem_write;
    reg [1:0]  idex_mem_to_reg;
    reg        idex_branch;
    reg        idex_jump;
    reg [2:0]  idex_funct3;

    always @(posedge clk) begin
        if (rst || flush) begin
            // Bubble: all control signals deasserted, addresses zeroed
            idex_pc         <= 32'h0;
            idex_pc_plus4   <= 32'h0;
            idex_rs1_data   <= 32'h0;
            idex_rs2_data   <= 32'h0;
            idex_imm        <= 32'h0;
            idex_rs1_addr   <= 5'h0;
            idex_rs2_addr   <= 5'h0;
            idex_rd_addr    <= 5'h0;
            idex_alu_op     <= 4'hF;   // NOP opcode (spec §7.1)
            idex_alu_src    <= 1'b0;
            idex_reg_write  <= 1'b0;
            idex_mem_read   <= 1'b0;
            idex_mem_write  <= 1'b0;
            idex_mem_to_reg <= 2'b00;
            idex_branch     <= 1'b0;
            idex_jump       <= 1'b0;
            idex_funct3     <= 3'h0;
        end else if (!stall) begin
            idex_pc         <= ifid_pc;
            idex_pc_plus4   <= ifid_pc_plus4;
            idex_rs1_data   <= rf_rdata1_D;
            idex_rs2_data   <= rf_rdata2_D;
            idex_imm        <= immD;
            idex_rs1_addr   <= rs1_addr_D;
            idex_rs2_addr   <= rs2_addr_D;
            idex_rd_addr    <= rd_addr_D;
            idex_alu_op     <= alu_op_D;
            idex_alu_src    <= alu_src_D;
            idex_reg_write  <= reg_write_D;
            idex_mem_read   <= mem_read_D;
            idex_mem_write  <= mem_write_D;
            idex_mem_to_reg <= mem_to_reg_D;
            idex_branch     <= branch_D;
            idex_jump       <= jump_D;
            idex_funct3     <= funct3;
        end
        // stall: hold (no else branch needed)
    end

// =============================================================================
// 5.  EX STAGE
// =============================================================================

    // --- Forwarding muxes (spec §7.3) ---
    // Forward sources: EX/MEM ALU result and MEM/WB writeback data
    wire [31:0] exmem_alu_result;  // declared forward; driven by EX/MEM reg
    wire [31:0] memwb_alu_result;  // declared forward; driven by MEM/WB reg
    wire [31:0] memwb_mem_data;    // declared forward; driven by MEM/WB reg
    wire [1:0]  memwb_mem_to_reg;  // declared forward

    // WB mux result (used as forwarding source from MEM/WB stage)
    // reuses wb_wdata declared in section 3
    wire [31:0] fwd_src_a;
    wire [31:0] fwd_src_b_pre; // before alu_src mux

    assign fwd_src_a = (fwd_a_sel == 2'b01) ? exmem_alu_result :
                       (fwd_a_sel == 2'b10) ? wb_wdata          :
                                              idex_rs1_data;

    assign fwd_src_b_pre = (fwd_b_sel == 2'b01) ? exmem_alu_result :
                           (fwd_b_sel == 2'b10) ? wb_wdata          :
                                                  idex_rs2_data;

    // ALU src B mux: register data vs immediate (spec §5.2 idex_alu_src)
    wire [31:0] alu_operand_b;
    assign alu_operand_b = idex_alu_src ? idex_imm : fwd_src_b_pre;

    // --- ALU (spec §6.4) ---
    wire [31:0] alu_result_E;
    wire        alu_zero_E;

    alu ALU (
        .operand_a (fwd_src_a),
        .operand_b (alu_operand_b),
        .alu_op    (idex_alu_op),
        .result    (alu_result_E),
        .zero      (alu_zero_E)
    );

    // --- Branch and Jump Unit (spec §6.6) ---
    branch_unit BRANCH_UNIT (
        .rs1_data     (fwd_src_a),
        .rs2_data     (fwd_src_b_pre),
        .pc           (idex_pc),
        .pc_plus4     (idex_pc_plus4),
        .imm          (idex_imm),
        .funct3       (idex_funct3),
        .branch       (idex_branch),
        .jump         (idex_jump),
        .branch_taken (branch_taken),
        .branch_target(branch_target)
    );

// =============================================================================
// 6.  EX/MEM PIPELINE REGISTER  (spec §5.3)
// =============================================================================

    reg [31:0] exmem_pc_plus4;
    // exmem_alu_result declared forward above as wire; redeclare as reg here
    // Verilog requires a single driver, so use a reg and wire alias
    reg  [31:0] exmem_alu_result_r;
    assign exmem_alu_result = exmem_alu_result_r;

    reg [31:0] exmem_rs2_data;
    reg [4:0]  exmem_rd_addr;
    reg        exmem_zero;
    reg        exmem_reg_write;
    reg        exmem_mem_read;
    reg        exmem_mem_write;
    reg [1:0]  exmem_mem_to_reg;
    reg        exmem_branch;
    reg        exmem_jump;
    reg [2:0]  exmem_funct3;

    always @(posedge clk) begin
        if (rst) begin
            exmem_pc_plus4    <= 32'h0;
            exmem_alu_result_r<= 32'h0;
            exmem_rs2_data    <= 32'h0;
            exmem_rd_addr     <= 5'h0;
            exmem_zero        <= 1'b0;
            exmem_reg_write   <= 1'b0;
            exmem_mem_read    <= 1'b0;
            exmem_mem_write   <= 1'b0;
            exmem_mem_to_reg  <= 2'b00;
            exmem_branch      <= 1'b0;
            exmem_jump        <= 1'b0;
            exmem_funct3      <= 3'h0;
        end else begin
            exmem_pc_plus4    <= idex_pc_plus4;
            exmem_alu_result_r<= alu_result_E;
            exmem_rs2_data    <= fwd_src_b_pre; // post-forwarding store data
            exmem_rd_addr     <= idex_rd_addr;
            exmem_zero        <= alu_zero_E;
            exmem_reg_write   <= idex_reg_write;
            exmem_mem_read    <= idex_mem_read;
            exmem_mem_write   <= idex_mem_write;
            exmem_mem_to_reg  <= idex_mem_to_reg;
            exmem_branch      <= idex_branch;
            exmem_jump        <= idex_jump;
            exmem_funct3      <= idex_funct3;
        end
    end

// =============================================================================
// 7.  MEM STAGE  (spec §6.7)
// =============================================================================

    wire [31:0] mem_rdata_M;

    data_mem DMEM (
        .clk       (clk),
        .addr      (exmem_alu_result),
        .wdata     (exmem_rs2_data),
        .mem_read  (exmem_mem_read),
        .mem_write (exmem_mem_write),
        .funct3    (exmem_funct3),
        .rdata     (mem_rdata_M)
    );

// =============================================================================
// 8.  MEM/WB PIPELINE REGISTER  (spec §5.4)
// =============================================================================

    // These are wires declared forward in section 3/5 — back them with regs
    reg [31:0] memwb_alu_result_r;
    assign memwb_alu_result = memwb_alu_result_r;

    reg [31:0] memwb_mem_data_r;
    assign memwb_mem_data = memwb_mem_data_r;

    reg [31:0] memwb_pc_plus4_r;
    reg [4:0]  memwb_rd_addr_r;
    reg        memwb_reg_write_r;
    reg [1:0]  memwb_mem_to_reg_r;
    assign memwb_mem_to_reg = memwb_mem_to_reg_r;

    always @(posedge clk) begin
        if (rst) begin
            memwb_alu_result_r  <= 32'h0;
            memwb_mem_data_r    <= 32'h0;
            memwb_pc_plus4_r    <= 32'h0;
            memwb_rd_addr_r     <= 5'h0;
            memwb_reg_write_r   <= 1'b0;
            memwb_mem_to_reg_r  <= 2'b00;
        end else begin
            memwb_alu_result_r  <= exmem_alu_result;
            memwb_mem_data_r    <= mem_rdata_M;
            memwb_pc_plus4_r    <= exmem_pc_plus4;
            memwb_rd_addr_r     <= exmem_rd_addr;
            memwb_reg_write_r   <= exmem_reg_write;
            memwb_mem_to_reg_r  <= exmem_mem_to_reg;
        end
    end

// =============================================================================
// 9.  WB STAGE — Write-Back Mux  (spec §7.2)
// =============================================================================

    // wb_wdata, wb_rd_addr, wb_reg_write declared in section 3
    assign wb_rd_addr   = memwb_rd_addr_r;
    assign wb_reg_write = memwb_reg_write_r;

    assign wb_wdata = (memwb_mem_to_reg_r == 2'b00) ? memwb_alu_result_r :  // ALU result
                      (memwb_mem_to_reg_r == 2'b01) ? memwb_mem_data_r    :  // Load data
                      (memwb_mem_to_reg_r == 2'b10) ? memwb_pc_plus4_r    :  // JAL/JALR link
                                                      32'h0;                  // Reserved

// =============================================================================
// 10. HAZARD DETECTION + FORWARDING UNIT  (spec §6.8)
// =============================================================================

    hazard_unit HAZARD (
        .idex_rs1_addr  (idex_rs1_addr),
        .idex_rs2_addr  (idex_rs2_addr),
        .idex_rd_addr   (idex_rd_addr),
        .idex_mem_read  (idex_mem_read),
        .exmem_rd_addr  (exmem_rd_addr),
        .exmem_reg_write(exmem_reg_write),
        .memwb_rd_addr  (memwb_rd_addr_r),
        .memwb_reg_write(memwb_reg_write_r),
        .stall          (stall),
        .flush          (flush),
        .fwd_a_sel      (fwd_a_sel),
        .fwd_b_sel      (fwd_b_sel)
    );

// =============================================================================
// 11. DEBUG / TESTBENCH PORTS
// =============================================================================

    assign tb_pc          = pcF;
    assign tb_alu_result  = alu_result_E;
    assign tb_reg_wb_data = wb_wdata;
    assign tb_reg_wb_addr = wb_rd_addr;
    assign tb_reg_wb_en   = wb_reg_write;

endmodule

// =============================================================================
// PC Register — simple enable-stall register
// =============================================================================
module pc_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (rst)    pc <= 32'h0;
        else if (en) pc <= pc_next;
        // en == 0: hold (stall)
    end
endmodule