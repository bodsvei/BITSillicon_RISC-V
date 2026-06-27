// Contributor: Soham Sawant
// =============================================================================
// rtl/mem_stage/data_mem.v — Parameterised Byte‑Addressable Data Memory
// =========================================================================
//
// This is the data memory (RAM) of the processor.  It handles all load and
// store instructions:  LB, LH, LW, LBU, LHU, SB, SH, SW.
//
// MEMORY SIZE
//   The number of 32‑bit words is controlled by the parameter DEPTH.
//   Default = 512 words (2048 bytes = 2 KB).  To change the size, just
//   override DEPTH when you instantiate this module – no internal code
//   changes are needed.  The address width is calculated automatically
//   from DEPTH using $clog2 (the ceiling‑of‑log2 function).
//
//   Example:  data_mem #(.DEPTH(1024)) DMEM (...);  // 4 KB memory
//
// READ / WRITE BEHAVIOUR
//   Read  – combinational.  As soon as the address or control signals
//           change, the data appears on 'rdata'.  This saves a clock cycle
//           for loads and is the standard design for single‑cycle memory.
//   Write – synchronous.  Data is stored only on the rising edge of the
//           clock when mem_write is high.
//
// ACCESS SIZES
//   The funct3[1:0] bits decide the access width:
//     00 → byte
//     01 → halfword (2 bytes)
//     10 → word (4 bytes)
//   The funct3[2] bit distinguishes signed/unsigned loads, but that is
//   handled later by the load_extend module.  Here we always zero‑extend
//   the upper bits of the read data.
//
//   Only aligned accesses are expected (word at address multiple of 4,
//   halfword at even address).  The hardware does not crash on misaligned
//   addresses, but it will select the wrong halfword if the address is odd.
//
// BYTE ORDER
//   Little‑endian (RISC‑V standard).  Byte 0 is the least significant byte.
//   Halfword at offset 0 uses bits 15..0; halfword at offset 2 uses bits
//   31..16.
//
// PARAMETERISATION
//   DEPTH   : number of 32‑bit words (default 512)
//   The internal address bus word_addr is automatically sized to
//   [ADDR_WIDTH‑1:0], where ADDR_WIDTH = $clog2(DEPTH).
//   The byte offset (addr[1:0]) is always 2 bits.
// =============================================================================

module data_mem #(
    parameter DEPTH = 512                     // words in memory (power‑of‑2 recommended)
) (
    input  wire        clk,                   // Global clock
    input  wire [31:0] addr,                  // Byte address (from ALU result)
    input  wire [31:0] wdata,                 // Data to store (from rs2 after forwarding)
    input  wire        mem_read,              // Load enable (1 = we are reading)
    input  wire        mem_write,             // Store enable (1 = we are writing)
    input  wire [2:0]  funct3,                // funct3 field (size + signedness)
    output wire [31:0] rdata                  // Read data (combinational)
);

    // ----- Auto‑compute the number of address bits -----
    localparam ADDR_WIDTH = $clog2(DEPTH);    // e.g. DEPTH=512 → 9 bits

    // ----- The actual storage array -----
    reg [31:0] mem [0:DEPTH-1];

    // ----- Split the byte address into word index and byte lane -----
    //       word_addr   = which 32‑bit word we are accessing
    //       byte_offset = which byte inside that word (0, 1, 2, 3)
    wire [ADDR_WIDTH-1:0] word_addr   = addr[ADDR_WIDTH+1:2];
    wire [1:0]            byte_offset = addr[1:0];

    // ==========================================================================
    // READ PATH (combinational)
    // ==========================================================================
    // For loads, we always read a full 32‑bit word, then extract the
    // required bytes/halfword.  The upper bits are zeroed.  Later,
    // load_extend.v will sign‑extend them for LB/LH if needed.
    // ==========================================================================
    reg [31:0] rd_pre;                         // temporary raw read result

    always @(*) begin
        rd_pre = 32'h0;                        // start clean (safety for undefined cases)
        case (funct3[1:0])                     // only care about access size
            2'b00: begin                       // Byte load
                // Pick one byte from the word, using byte_offset as index.
                // Syntax [base +: width] selects a bit‑slice of 8 bits.
                rd_pre[7:0] = mem[word_addr][byte_offset*8 +: 8];
            end
            2'b01: begin                       // Halfword load
                // A halfword is 2 bytes.  Address bit 1 tells us which half.
                // byte_offset[1] == 0 → lower half (bits 15..0)
                // byte_offset[1] == 1 → upper half (bits 31..16)
                if (byte_offset[1] == 1'b0)
                    rd_pre[15:0] = mem[word_addr][15:0];
                else
                    rd_pre[15:0] = mem[word_addr][31:16];
            end
            2'b10: begin                       // Word load
                rd_pre = mem[word_addr];
            end
            default: rd_pre = 32'h0;           // Should never happen
        endcase
    end

    assign rdata = rd_pre;                     // Drive the output

    // ==========================================================================
    // WRITE PATH (synchronous)
    // ==========================================================================
    // Stores happen on the rising clock edge.  We must write ONLY the bytes
    // that the instruction intends to change.  All other bytes in the same
    // word stay untouched – otherwise we’d corrupt other data.
    // ==========================================================================
    always @(posedge clk) begin
        if (mem_write) begin
            case (funct3[1:0])
                2'b00: // Store byte
                    // Replace only the addressed byte lane.
                    mem[word_addr][byte_offset*8 +: 8] <= wdata[7:0];
                2'b01: // Store halfword
                    // Write either the lower or upper 16 bits of the word.
                    if (byte_offset[1] == 1'b0)
                        mem[word_addr][15:0]  <= wdata[15:0];
                    else
                        mem[word_addr][31:16] <= wdata[15:0];
                2'b10: // Store word
                    // Overwrite the entire 32‑bit word.
                    mem[word_addr] <= wdata;
                // default: no store (safety)
            endcase
        end
    end

endmodule
