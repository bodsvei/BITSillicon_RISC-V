`timescale 1ns/1ps

module tb_riscv_bubble_sort;

    parameter CLK_HALF  = 5;
    parameter MAX_CYCLES = 2000;

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
    defparam DUT.IMEM.HEX_FILE = "programs/hex/bubble_sort.hex";

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
        $dumpfile("dump_sort.vcd");
        $dumpvars(0, tb_riscv_bubble_sort);
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

    // After enough cycles, verify array is sorted
    initial begin
        @(negedge rst);
        repeat(1500) @(posedge clk);

        $display("\n--- Bubble sort result check (8 elements at 0x200) ---");
        begin : check
            integer i;
            integer got, exp;
            // input [8,3,7,1,5,9,2,6] → sorted ascending [1,2,3,5,6,7,8,9]
            integer sorted [0:7];
            sorted[0]=1; sorted[1]=2; sorted[2]=3; sorted[3]=5;
            sorted[4]=6; sorted[5]=7; sorted[6]=8; sorted[7]=9;

            for (i = 0; i < 8; i = i + 1) begin
                // base = 0x200 = 512 bytes = word 128
                got = DUT.DMEM.mem[128 + i];
                exp = sorted[i];
                if (got !== exp) begin
                    $display("  FAIL arr[%0d]: got %0d, expected %0d", i, got, exp);
                    errors = errors + 1;
                end else begin
                    $display("  PASS arr[%0d] = %0d", i, got);
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
