// Standalone hazard detection unit (logic lives in hazard_unit.v for top integration)
module hazard_detect (
    input  wire [4:0] idex_rs1_addr,
    input  wire [4:0] idex_rs2_addr,
    input  wire [4:0] idex_rd_addr,
    input  wire       idex_mem_read,
    input  wire       branch_taken,
    output wire       stall,
    output wire       flush
);
    assign stall = idex_mem_read &&
                   ((idex_rd_addr == idex_rs1_addr) || (idex_rd_addr == idex_rs2_addr)) &&
                   (idex_rd_addr != 5'h0);
    assign flush = branch_taken;
endmodule
