`timescale 1ns/1ps

module tb_riscv_factorial;

    parameter CLK_HALF  = 5;
    parameter NUM_INST  = 300; // Approx number of instructions executed
    parameter TOTAL_CYCLES = (NUM_INST + 4) * 2;

    reg  clk = 0;
    reg  rst = 1;

    riscv_top DUT (
        .clk           (clk),
        .rst           (rst)
    );
    defparam DUT.IMEM.HEX_FILE = "programs/hex/factorial.hex";

    always #CLK_HALF clk = ~clk;

    integer errors = 0;

    initial begin
        rst = 1;
        repeat(2) @(posedge clk);
        @(negedge clk);
        rst = 0;
    end

    `ifdef DUMP_VCD
    initial begin
        $dumpfile("dump_fact.vcd");
        $dumpvars(0, tb_riscv_factorial);
    end
    `endif

    // Monitor register writes so we can see progress
    always @(posedge clk) begin
        if (!rst && DUT.wb_reg_write && DUT.wb_rd_addr != 0)
            $display("[%0t] WB: x%0d = %0d", $time, DUT.wb_rd_addr, $signed(DUT.wb_wdata));
    end

    // After computed delay, check 7! stored at word address 4 (byte 0x10)
    initial begin
        // Wait for reset
        @(negedge rst);
        
        // Wait calculated total delay
        #(CLK_HALF * 2 * TOTAL_CYCLES);

        $display("\n--- Factorial result check (7! stored at mem[4] = byte 0x10) ---");
        begin : check
            integer got;
            got = DUT.DMEM.mem[4];   // byte addr 0x10 = word 4
            if (got !== 5040) begin
                $display("  FAIL 7! = %0d, expected 5040", got);
                errors = errors + 1;
            end else begin
                $display("  PASS 7! = %0d", got);
            end
        end

        if (errors == 0)
            $display("\nALL PASS");
        else
            $display("\n%0d FAILURES", errors);

        $finish;
    end

endmodule
