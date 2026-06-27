// ============================================================
// Testbench   : tb_branch_unit
// File        : tb/unit/tb_branch_unit.v
// Tests       : branch_unit.v
// Contributor : Aparna
// ============================================================

module tb_branch_unit;

    // inputs to branch_unit (we control these)
    reg        Branch;
    reg        Jump;
    reg        is_jalr;
    reg [2:0]  funct3;
    reg [3:0]  ALUFlags;
    reg [31:0] PC;
    reg [31:0] rs1;
    reg [31:0] B_imm;
    reg [31:0] J_imm;
    reg [31:0] I_imm;

    // outputs from branch_unit (we just observe these)
    wire        PCSrc;
    wire [31:0] PCTarget;

    // connect testbench to your module
    branch_unit uut (
        .Branch  (Branch),
        .Jump    (Jump),
        .is_jalr (is_jalr),
        .funct3  (funct3),
        .ALUFlags(ALUFlags),
        .PC      (PC),
        .rs1     (rs1),
        .B_imm   (B_imm),
        .J_imm   (J_imm),
        .I_imm   (I_imm),
        .PCSrc   (PCSrc),
        .PCTarget(PCTarget)
    );

    initial begin
        $display("=============================");
        $display("   Branch Unit Test Cases    ");
        $display("=============================");

        Branch=0; Jump=0; is_jalr=0;
        funct3=0; ALUFlags=0;
        PC=0; rs1=0; B_imm=0; J_imm=0; I_imm=0;
        #10;

        Branch=1; Jump=0; is_jalr=0;
        funct3=3'b000;
        ALUFlags=4'b0100;
        PC=32'h100;
        B_imm=32'h8;
        #10;
        $display("TEST 1 BEQ taken   : PCSrc=%b (want 1), PCTarget=%h (want 108)", PCSrc, PCTarget);

        ALUFlags=4'b0000;
        #10;
        $display("TEST 2 BEQ no take : PCSrc=%b (want 0)", PCSrc);

        funct3=3'b001;
        ALUFlags=4'b0000;
        #10;
        $display("TEST 3 BNE taken   : PCSrc=%b (want 1)", PCSrc);

        funct3=3'b100;
        ALUFlags=4'b1000;
        #10;
        $display("TEST 4 BLT taken   : PCSrc=%b (want 1)", PCSrc);

        ALUFlags=4'b0000;
        #10;
        $display("TEST 5 BLT no take : PCSrc=%b (want 0)", PCSrc);

        Branch=0; Jump=1; is_jalr=0;
        PC=32'h200;
        J_imm=32'h40;
        #10;
        $display("TEST 6 JAL         : PCSrc=%b (want 1), PCTarget=%h (want 240)", PCSrc, PCTarget);

        Jump=1; is_jalr=1;
        rs1=32'hABC;
        I_imm=32'h4;
        #10;
        $display("TEST 7 JALR        : PCSrc=%b (want 1), PCTarget=%h (want ac0)", PCSrc, PCTarget);

        rs1=32'hABC;
        I_imm=32'h3;
        #10;
        $display("TEST 8 JALR align  : PCTarget=%h (want abe)", PCTarget);

        Branch=0; Jump=0; is_jalr=0;
        funct3=3'b000; ALUFlags=4'b0000;
        #10;
        $display("TEST 9 HALT check  : PCSrc=%b (want 0)", PCSrc);

        $display("=============================");
        $display("        Tests Done!          ");
        $display("=============================");
        $finish;
    end

endmodule