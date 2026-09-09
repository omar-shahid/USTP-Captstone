#!/bin/bash
# ============================================================
#  run_lec.sh — Cadence Conformal LEC Execution Wrapper (Linux)
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJ_ROOT"

# Create report directory
mkdir -p lec/reports

echo "======================================================"
echo " Starting Cadence Conformal LEC"
echo " Golden:  RTL (risc_v)"
echo " Revised: synthesis/output/risc_v_netlist.v"
echo "======================================================"

if [ "$1" == "-gui" ]; then
    echo "Running in GUI mode..."
    lec -gui -dofile lec/run_lec.do
else
    echo "Running in Batch (non-GUI) mode..."
    lec -nogui -dofile lec/run_lec.do -logfile lec/reports/lec.log
fi
