PROJ := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
RTL  := $(shell find rtl -name "*.v" | sort)
IVFLAGS := -Wall -Wno-timescale

.PHONY: all sim unit wave clean asm

all: sim unit

# Assemble all programs
asm:
	python3 scripts/assemble.py programs/asm/fibonacci.s  -o programs/hex/fibonacci.hex
	python3 scripts/assemble.py programs/asm/bubble_sort.s -o programs/hex/bubble_sort.hex
	python3 scripts/assemble.py programs/asm/factorial.s  -o programs/hex/factorial.hex

# Run all three integration tests (HEX_FILE set via defparam in each testbench)
sim: asm
	@echo "=== fibonacci ==="
	@iverilog $(IVFLAGS) -o /tmp/riscv_fibonacci.vvp \
		tb/integration/tb_riscv_top.v $(RTL) && vvp /tmp/riscv_fibonacci.vvp
	@echo ""
	@echo "=== bubble_sort ==="
	@iverilog $(IVFLAGS) -o /tmp/riscv_bubble_sort.vvp \
		tb/integration/tb_riscv_bubble_sort.v $(RTL) && vvp /tmp/riscv_bubble_sort.vvp
	@echo ""
	@echo "=== factorial ==="
	@iverilog $(IVFLAGS) -o /tmp/riscv_factorial.vvp \
		tb/integration/tb_riscv_factorial.v $(RTL) && vvp /tmp/riscv_factorial.vvp

# Unit tests
unit:
	@for tb in tb/unit/tb_*.v; do \
		name=$$(basename $$tb .v); \
		echo "--- $$name ---"; \
		iverilog $(IVFLAGS) -o /tmp/$$name.vvp $$tb $(RTL) && vvp /tmp/$$name.vvp || true; \
	done

# Dump VCD for a specific program (usage: make wave PROG=fibonacci)
PROG ?= fibonacci
wave: asm
	iverilog $(IVFLAGS) -DDUMP_VCD -o /tmp/riscv_$(PROG)_vcd.vvp \
		-P tb_riscv_top.DUT.IMEM.HEX_FILE=\"programs/hex/$(PROG).hex\" \
		tb/integration/tb_riscv_top.v $(RTL) && vvp /tmp/riscv_$(PROG)_vcd.vvp
	gtkwave dump.vcd &

clean:
	rm -f /tmp/riscv_*.vvp /tmp/tb_*.vvp dump*.vcd
