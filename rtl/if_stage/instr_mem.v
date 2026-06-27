module instr_mem (
    input  wire [31:0] pc,    // Connected directly to the PC
    output wire [31:0] instr  // The instruction fetched from that address
);

    parameter DEPTH    = 256;                          // words (default 1 KB)
    parameter HEX_FILE = "programs/hex/fibonacci.hex";

    localparam ADDR_BITS = $clog2(DEPTH);

    reg [31:0] memory_array [0:DEPTH-1];

    initial $readmemh(HEX_FILE, memory_array);

    assign instr = memory_array[pc[ADDR_BITS+1:2]];

endmodule
