module if_id_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,       // Stall signal (active low: 1=run, 0=stall)
    input  wire        clr,      // Flush signal (1=flush, 0=run)
    
    // Inputs coming from the IF stage
    input  wire [31:0] pc_f,     
    input  wire [31:0] instr_f,  
    
    // Outputs going into the ID stage
    output reg  [31:0] pc_d,     
    output reg  [31:0] instr_d   
);

    always @(posedge clk) begin
        if (rst) begin
            pc_d    <= 32'h00000000;
            instr_d <= 32'h00000000;
        end 
        else if (clr) begin
            // We guessed the wrong branch! Flush it by inserting a NOP.
            // 32'h00000013 is 'addi x0, x0, 0' which is the standard RISC-V NOP
            pc_d    <= 32'h00000000;
            instr_d <= 32'h00000013; 
        end 
        else if (en) begin
            // Normal operation: pass the data from IF to ID
            pc_d    <= pc_f;
            instr_d <= instr_f;
        end
        // If en == 0, it stalls (keeps holding the current values)
    end

endmodule
