`timescale 1ns/1ps

module tb_riscv_top;

    parameter CLK_HALF = 5;
    parameter MAX_CYCLES = 500;
    parameter HEX_FILE = "programs/hex/fibonacci.hex";

    reg  clk = 0;
    reg  rst = 1;

    wire [31:0] tb_pc;
    wire [31:0] tb_alu_result;
    wire [31:0] tb_reg_wb_data;
    wire [4:0]  tb_reg_wb_addr;
    wire        tb_reg_wb_en;

    riscv_top DUT (
        .clk           (clk),
        .rst           (rst),
        .tb_pc         (tb_pc),
        .tb_alu_result (tb_alu_result),
        .tb_reg_wb_data(tb_reg_wb_data),
        .tb_reg_wb_addr(tb_reg_wb_addr),
        .tb_reg_wb_en  (tb_reg_wb_en)
    );
    defparam DUT.IMEM.HEX_FILE = "programs/hex/fibonacci.hex";

    always #CLK_HALF clk = ~clk;

    integer cycle = 0;
    integer errors = 0;

    // Hold reset for 2 cycles
    initial begin
        rst = 1;
        repeat(2) @(posedge clk);
        @(negedge clk);
        rst = 0;
    end

    // VCD dump if DUMP_VCD defined
    `ifdef DUMP_VCD
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_riscv_top);
    end
    `endif

    // Monitor register writes
    always @(posedge clk) begin
        if (!rst && tb_reg_wb_en && tb_reg_wb_addr != 0) begin
            $display("[%0t] WB: x%0d = 0x%08X (%0d)",
                     $time, tb_reg_wb_addr, tb_reg_wb_data, $signed(tb_reg_wb_data));
        end
    end

    // Cycle counter and timeout
    always @(posedge clk) begin
        if (!rst) begin
            cycle = cycle + 1;
            $display("PC=%08X instr=%08X", DUT.pcF, DUT.instrF);
            if (cycle >= MAX_CYCLES) begin
                $display("TIMEOUT after %0d cycles — stopping", MAX_CYCLES);
                $finish;
            end
        end
    end

    // After enough cycles, read back memory and check fibonacci results
    initial begin
        // Wait for reset + enough cycles for fibonacci to finish or HALT
        @(negedge rst);
        while (DUT.instrF !== 32'hFFFFFFFF && cycle < MAX_CYCLES) begin
            @(posedge clk);
        end
        
        // Wait 4 cycles to let the instructions before HALT finish the pipeline
        repeat(4) @(posedge clk);

        $display("\n--- Fibonacci result check (x1..x10 at mem 0x1000) ---");
        // Read data memory via DUT.DMEM instance
        begin : check
            integer i;
            integer got, exp;
            integer fibs [0:9];
            fibs[0] = 0;  fibs[1] = 1;  fibs[2] = 1;  fibs[3] = 2;
            fibs[4] = 3;  fibs[5] = 5;  fibs[6] = 8;  fibs[7] = 13;
            fibs[8] = 21; fibs[9] = 34;

            for (i = 0; i < 10; i = i + 1) begin
                // data_mem word address = byte_addr / 4 = 0x100/4 + i = 64 + i
                got = $signed(DUT.DMEM.mem[64 + i]);
                exp = fibs[i];
                if (got !== exp) begin
                    $display("  FAIL fib[%0d]: got %0d, expected %0d", i, got, exp);
                    errors = errors + 1;
                end else begin
                    $display("  PASS fib[%0d] = %0d", i, got);
                end
            end
        end

        if (errors == 0)
            $display("\nALL PASS");
        else
            $display("\n%0d FAILURES", errors);

        $finish;
    end

endmodule
