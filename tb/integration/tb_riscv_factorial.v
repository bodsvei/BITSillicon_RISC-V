`timescale 1ns/1ps

module tb_riscv_factorial;

    parameter CLK_HALF  = 5;
    parameter MAX_CYCLES = 1000;

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
    defparam DUT.IMEM.HEX_FILE = "programs/hex/factorial.hex";

    always #CLK_HALF clk = ~clk;

    integer cycle  = 0;
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

    always @(posedge clk) begin
        if (!rst) begin
            cycle = cycle + 1;
            if (cycle >= MAX_CYCLES) begin
                $display("TIMEOUT after %0d cycles", MAX_CYCLES);
                $finish;
            end
        end
    end

    // Monitor register writes so we can see progress
    always @(posedge clk) begin
        if (!rst && tb_reg_wb_en && tb_reg_wb_addr != 0)
            $display("[%0t] WB: x%0d = %0d", $time, tb_reg_wb_addr, $signed(tb_reg_wb_data));
    end

    // After enough cycles, check 7! stored at word address 4 (byte 0x10)
    initial begin
        // Wait for reset + enough cycles for factorial to finish or HALT
        @(negedge rst);
        while (DUT.instrF !== 32'hFFFFFFFF && cycle < MAX_CYCLES) begin
            @(posedge clk);
        end
        
        // Wait 4 cycles to let the instructions before HALT finish the pipeline
        repeat(4) @(posedge clk);

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
