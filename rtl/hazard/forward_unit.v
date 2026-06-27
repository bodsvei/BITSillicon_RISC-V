// Standalone forwarding unit (logic lives in hazard_unit.v for top integration)
// This file is a placeholder; the combined hazard_unit is what riscv_top.v uses.
module forward_unit (
    input  wire [4:0]  idex_rs1_addr,
    input  wire [4:0]  idex_rs2_addr,
    input  wire [4:0]  exmem_rd_addr,
    input  wire        exmem_reg_write,
    input  wire [4:0]  memwb_rd_addr,
    input  wire        memwb_reg_write,
    output wire [1:0]  fwd_a_sel,
    output wire [1:0]  fwd_b_sel
);
    assign fwd_a_sel = (exmem_reg_write && exmem_rd_addr != 5'h0 && exmem_rd_addr == idex_rs1_addr) ? 2'b01 :
                       (memwb_reg_write && memwb_rd_addr != 5'h0 && memwb_rd_addr == idex_rs1_addr) ? 2'b10 :
                                                                                                       2'b00;
    assign fwd_b_sel = (exmem_reg_write && exmem_rd_addr != 5'h0 && exmem_rd_addr == idex_rs2_addr) ? 2'b01 :
                       (memwb_reg_write && memwb_rd_addr != 5'h0 && memwb_rd_addr == idex_rs2_addr) ? 2'b10 :
                                                                                                       2'b00;
endmodule
