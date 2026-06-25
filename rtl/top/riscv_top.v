
module riscv_top (
    input wire clk,
    input wire rst
);

    // --- IF Stage Wires ---
    wire [31:0] pcF;          // Current PC in Fetch stage
    wire [31:0] pcPlus4F;     // PC + 4
    wire [31:0] pcNextF;      // The actual next PC
    
    wire [31:0] pctargetE;    // Branch target coming from EX stage
    wire        PCSrcE;       // Branch decision coming from Branch Unit
    wire        StallF;
    // ==========================================
    // THIS IS WHERE THE +4 AND MUX LOGIC LIVES
    // ==========================================
    
    // 1. The +4 Adder logic
    assign pcPlus4F = pcF + 32'd4;
    
    // 2. The Next-PC Multiplexer logic
    // If PCSrcE is 1 (branch taken), use pctargetE. Otherwise, use PC + 4.
    assign pcNextF = (PCSrcE) ? pctargetE : pcPlus4F;

    // ==========================================

    // 3. Instantiate the PC Register (passing in pcNextF)
    pc_reg PC_REG_INST (
        .clk     (clk),
        .rst     (rst),
        .en      (~StallF), // Wait signal from Hazard Unit
        .pc_next (pcNextF),
        .pc      (pcF)
    );

    // ... (rest of the pipeline instantiations like Instruction Memory, etc)

endmodule
