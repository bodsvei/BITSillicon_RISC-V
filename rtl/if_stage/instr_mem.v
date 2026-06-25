module instr_mem (
    input  wire [31:0] addr,  // Connected directly to the PC
    output wire [31:0] instr  // The instruction fetched from that address
);

    // Create an array to act as our memory (e.g., 256 words of 32 bits each)
    reg [31:0] memory_array [0:255]; 

    // RISC-V is byte-addressed, meaning every address points to 1 byte.
    // But our memory stores full 32-bit words (4 bytes).
    // So, we divide the PC address by 4 (by shifting right 2 bits: addr[31:2]) 
    // to find the correct word index in our array.
    
    assign instr = memory_array[addr[31:2]];

endmodule
