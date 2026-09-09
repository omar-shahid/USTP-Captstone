# ============================================================
#  run_lec.ps1 — Cadence Conformal LEC Execution Wrapper (PowerShell)
# ============================================================

param(
    [switch]$Gui
)

$ProjRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjRoot

# Create reports directory
if (-not (Test-Path "lec/reports")) {
    New-Item -ItemType Directory -Path "lec/reports" | Out-Null
}

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Starting Cadence Conformal LEC" -ForegroundColor Cyan
Write-Host " Golden:  RTL (risc_v)" -ForegroundColor Gray
Write-Host " Revised: synthesis/output/risc_v_netlist.v" -ForegroundColor Gray
Write-Host "======================================================" -ForegroundColor Cyan

if ($Gui) {
    Write-Host "Running in GUI mode..." -ForegroundColor Yellow
    lec -gui -dofile lec/run_lec.do
} else {
    Write-Host "Running in Batch (non-GUI) mode..." -ForegroundColor Yellow
    lec -nogui -dofile lec/run_lec.do -logfile lec/reports/lec.log
}
