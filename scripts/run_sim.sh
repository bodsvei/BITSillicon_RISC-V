#!/usr/bin/env bash
# run_sim.sh — compile and run RTL simulations with Icarus Verilog
set -euo pipefail

PROJ=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJ"

RTL_DIRS="rtl/top rtl/if_stage rtl/id_stage rtl/control rtl/ex_stage rtl/mem_stage rtl/wb_stage rtl/hazard"
RTL_FILES=$(for d in $RTL_DIRS; do find "$d" -name "*.v" 2>/dev/null; done | tr '\n' ' ')

usage() {
    echo "Usage: $0 [unit|integration|all] [--vcd] [--program fibonacci|bubble_sort|factorial]"
    exit 1
}

MODE=${1:-integration}
VCD=""
PROGRAM="fibonacci"

shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --vcd)       VCD="-DDUMP_VCD" ;;
        --program)   PROGRAM="$2"; shift ;;
        -h|--help)   usage ;;
        *) echo "Unknown arg: $1"; usage ;;
    esac
    shift
done

HEX="programs/hex/${PROGRAM}.hex"

run_unit() {
    local tb="$1"
    local name=$(basename "$tb" .v)
    echo "=== Unit: $name ==="
    iverilog -o /tmp/${name}.vvp $tb $RTL_FILES 2>&1 || { echo "COMPILE FAIL"; return 1; }
    vvp /tmp/${name}.vvp
}

run_integration() {
    echo "=== Integration: tb_riscv_top (program=$PROGRAM) ==="
    # Pass HEX_FILE via defparam by overriding the parameter
    iverilog -o /tmp/tb_riscv_top.vvp $VCD \
        -P tb_riscv_top.HEX_FILE=\"$HEX\" \
        -P tb_riscv_top.DUT.IMEM.HEX_FILE=\"$HEX\" \
        tb/integration/tb_riscv_top.v $RTL_FILES 2>&1 \
    || { echo "COMPILE FAIL"; exit 1; }
    vvp /tmp/tb_riscv_top.vvp

    if [[ -n "$VCD" ]]; then
        echo ""
        echo "VCD written to dump.vcd — open with: gtkwave dump.vcd"
    fi
}

case "$MODE" in
    unit)
        for tb in tb/unit/tb_*.v; do
            run_unit "$tb" || true
        done
        ;;
    integration)
        run_integration
        ;;
    all)
        for tb in tb/unit/tb_*.v; do
            run_unit "$tb" || true
        done
        run_integration
        ;;
    *)
        usage
        ;;
esac
