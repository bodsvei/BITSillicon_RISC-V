// Combined hazard detection + forwarding unit as expected by riscv_top.v
module hazard_unit (
    // Sources of instruction currently in ID (for load-use stall detection)
    input  wire [4:0]  ifid_rs1_addr,
    input  wire [4:0]  ifid_rs2_addr,
    // Sources and destination of instruction currently in EX (for forwarding)
    input  wire [4:0]  idex_rs1_addr,
    input  wire [4:0]  idex_rs2_addr,
    input  wire [4:0]  idex_rd_addr,
    input  wire        idex_mem_read,
    input  wire [4:0]  exmem_rd_addr,
    input  wire        exmem_reg_write,
    input  wire [4:0]  memwb_rd_addr,
    input  wire        memwb_reg_write,
    output wire        stall,
    output wire        flush,
    output wire [1:0]  fwd_a_sel,
    output wire [1:0]  fwd_b_sel
);
    // Load-use hazard: load is in EX, following instruction is in ID.
    // Compare load's rd against the ID instruction's rs1/rs2.
    wire load_use = idex_mem_read &&
                    ((idex_rd_addr == ifid_rs1_addr) || (idex_rd_addr == ifid_rs2_addr)) &&
                    (idex_rd_addr != 5'h0);

    assign stall = load_use;
    // flush is driven by branch_taken from branch_unit in top; tie to 0 here
    // (riscv_top.v drives flush directly from branch_taken, not from this port)
    assign flush = 1'b0;

    // EX-EX forwarding (priority over MEM-EX)
    assign fwd_a_sel = (exmem_reg_write && exmem_rd_addr != 5'h0 && exmem_rd_addr == idex_rs1_addr) ? 2'b01 :
                       (memwb_reg_write && memwb_rd_addr != 5'h0 && memwb_rd_addr == idex_rs1_addr) ? 2'b10 :
                                                                                                       2'b00;

    assign fwd_b_sel = (exmem_reg_write && exmem_rd_addr != 5'h0 && exmem_rd_addr == idex_rs2_addr) ? 2'b01 :
                       (memwb_reg_write && memwb_rd_addr != 5'h0 && memwb_rd_addr == idex_rs2_addr) ? 2'b10 :
                                                                                                       2'b00;

endmodule
