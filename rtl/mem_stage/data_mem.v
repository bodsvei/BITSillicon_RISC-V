// Contributor: Soham Sawant
//=============================================================================
// rtl/mem_stage/data_mem.v
// "The Data Memory – where loads and stores really happen"
// =============================================================================
//
// This is a small, synchronous RAM that can read/write bytes, halfwords,
// and whole words.  Think of it like a tiny scratchpad that the CPU can
// peek at and poke into.
//
// A few design choices we made:
//   – The read is COMBINATIONAL.  As soon as the address or control changes,
//     the data appears on 'rdata'.  This saves a clock cycle for loads.
//   – The write is SYNCHRONOUS.  Data is actually stored only on the rising
//     edge of the clock, when 'mem_write' is high.
//   – It only handles aligned accesses.  We assume the program never asks for
//     a halfword from address 0x13, for example – but even if it does, the
//     hardware won't crash; it will just treat the address as if it were aligned.
//   – The memory is 2048 bytes deep (512 words).  That’s enough for small
//     test programs like Fibonacci or bubble sort.
//
// Byte ordering is little‑endian.  Byte 0 is the least significant byte of a
// word.  That's the RISC‑V standard, so we follow it religiously.
// =============================================================================

module data_mem (
    input  wire        clk,        // The heartbeat of the CPU
    input  wire [31:0] addr,       // Byte address we want to access
    input  wire [31:0] wdata,      // Data to write (for store instructions)
    input  wire        mem_read,   // '1' when we are doing a load
    input  wire        mem_write,  // '1' when we are doing a store
    input  wire [2:0]  funct3,     // Tells us the size and signedness of the access
    output wire [31:0] rdata       // Data that comes out during a load
);

    // ----- The actual storage -------------------------------------------------
    // 512 words of 32 bits each.  This is the heart of the memory.
    reg [31:0] mem [0:511];        // 512 entries, each 32 bits wide

    // ----- Address decoding ---------------------------------------------------
    // A byte address can be split into two pieces:
    //   word_addr   = which 32‑bit word we are touching
    //   byte_offset = which byte (or halfword) inside that word we want
    wire [8:0]  word_addr   = addr[10:2];   // 9 bits → 512 words
    wire [1:0]  byte_offset = addr[1:0];    // 2 bits → 0..3

    // ==========================================================================
    // READ PATH (combinational)
    // ==========================================================================
    // For loads, the CPU wants the data immediately.  We don't wait for a clock.
    // We always read the whole 32‑bit word and then pick the relevant bytes.
    // The 'load_extend' module later will decide whether to keep the upper bits
    // as zeros or to sign‑extend them (for LBU vs. LB, etc.).
    // ==========================================================================

    reg [31:0] rd_pre;      // temporary signal that holds the raw read result

    always @(*) begin
        // Start with all zeros – a clean slate
        rd_pre = 32'h0;

        // funct3[1:0] determines the access size:
        //   00 → byte
        //   01 → halfword
        //   10 → word
        // The third bit (funct3[2]) only matters for sign‑extension,
        // which is handled later in load_extend.  So we ignore it here.
        case (funct3[1:0])

            2'b00: begin
                // ---- Byte load ----
                // Extract exactly one byte from the word.
                // The byte is chosen by 'byte_offset'.
                // For example, if byte_offset is 2, we take the third byte (bits 23:16)
                // and put it into the lowest 8 bits of rd_pre.
                rd_pre[7:0] = mem[word_addr][byte_offset*8 +: 8];
            end

            2'b01: begin
                // ---- Halfword load ----
                // A halfword is 2 bytes.  The alignment rule says:
                //   - if address bit 1 is 0 → take the lower half (bits 15:0)
                //   - if address bit 1 is 1 → take the upper half (bits 31:16)
                // We use byte_offset[1] as the selector.
                if (byte_offset[1] == 1'b0)
                    rd_pre[15:0] = mem[word_addr][15:0];   // lower half
                else
                    rd_pre[15:0] = mem[word_addr][31:16];  // upper half
            end

            2'b10: begin
                // ---- Word load ----
                // Just pass the whole word through.  Easy.
                rd_pre = mem[word_addr];
            end

            default: begin
                // Should never happen, but just in case, drive zero.
                rd_pre = 32'h0;
            end
        endcase
    end

    // The final output of the memory is the raw (zero‑extended) value.
    // load_extend will take care of sign‑extension later.
    assign rdata = rd_pre;

    // ==========================================================================
    // WRITE PATH (synchronous)
    // ==========================================================================
    // Stores only happen on the rising edge of clk, and only when mem_write = 1.
    // We must write ONLY the bytes that the instruction intends to modify.
    // All other bytes in the same word must stay unchanged, otherwise we'd
    // corrupt data that the program stored earlier.
    // ==========================================================================

    always @(posedge clk) begin
        if (mem_write) begin
            // Same access size decoding as for reads
            case (funct3[1:0])

                2'b00: begin
                    // ---- Store byte ----
                    // Replace only the addressed byte lane.
                    // The other three bytes are left untouched.
                    mem[word_addr][byte_offset*8 +: 8] <= wdata[7:0];
                end

                2'b01: begin
                    // ---- Store halfword ----
                    // Write either the lower or upper 16 bits of the word,
                    // again using address bit 1 as the selector.
                    if (byte_offset[1] == 1'b0)
                        mem[word_addr][15:0]  <= wdata[15:0];  // lower half
                    else
                        mem[word_addr][31:16] <= wdata[15:0];  // upper half
                end

                2'b10: begin
                    // ---- Store word ----
                    // Overwrite the entire 32‑bit word.
                    mem[word_addr] <= wdata;
                end

                // default: no write (safety net)
            endcase
        end
    end
endmodule
