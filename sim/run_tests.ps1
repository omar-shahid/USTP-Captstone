# Automated Test Suite Runner for RISC-V + UART
$ErrorActionPreference = "Stop"
$StartTime = Get-Date

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  RISC-V & UART REGRESSION VERIFICATION SUITE RUNNER       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Compilation
Write-Host "`n[STEP 1] Compiling all RTL and Testbench modules..." -ForegroundColor Yellow
if (-not (Test-Path "work")) {
    vlib work
    vmap work work
}

$compileCmd = "vlog -timescale 1ns/1ps -work work -sv adder.v alu.v alu_control.v clk_div.v control_unit.v cu.v data_mem.v imm_ext.v instr_mem.v mux.v pc.v reg_file.v uart_tx.v uart_rx.v uart_regs.v risc_v.v tb/risc_v_isa_tb.v tb/uart_edge_tb.v tb/risc_v_uart_tb.v tb/uart_loopback_tb.v tb/risc_v_uart_full_tb.v tb/risc_v_hex_tb.v"
Invoke-Expression $compileCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Compilation failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[SUCCESS] All RTL and Testbenches compiled cleanly (0 errors)." -ForegroundColor Green

# 2. Testbenches to execute
$testbenches = @(
    @{ Name = "RISC-V ISA & Subunit Test"; Module = "risc_v_isa_tb"; Args = ""; Desc = "ALU, Immediates, Control Unit, Register File, Data Memory" },
    @{ Name = "UART Core & MMIO Edge Cases"; Module = "uart_edge_tb"; Args = ""; Desc = "TX/RX patterns, Glitch rejection, Framing errors, MMIO registers" },
    @{ Name = "RISC-V UART Serial Stream"; Module = "risc_v_uart_tb"; Args = ""; Desc = "CPU booting, polling UART MMIO, transmitting serial 'Hi' stream" },
    @{ Name = "UART Hardware Loopback"; Module = "uart_loopback_tb"; Args = ""; Desc = "Direct TX->RX loopback with CPU stream verification" },
    @{ Name = "Full Integration & Recovery"; Module = "risc_v_uart_full_tb"; Args = ""; Desc = "CPU serial TX, external RX injection, and mid-execution reset" },
    @{ Name = "RISC-V Hex-Loader SoC Test"; Module = "risc_v_hex_tb"; Args = "+HEX=assembly_codes/full_soc_test.hex"; Desc = "Dynamic loading and execution of full_soc_test.hex" }
)

$results = @()
$allPassed = $true

foreach ($tb in $testbenches) {
    Write-Host "`n----------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Running: $($tb.Name) ($($tb.Module))" -ForegroundColor Cyan
    Write-Host "Description: $($tb.Desc)" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

    $logFile = "$($tb.Module)_sim.log"
    $simCmd = "vsim -c -do `"run -all; quit -f`" work.$($tb.Module) $($tb.Args) -l $logFile"
    Invoke-Expression $simCmd

    $logContent = Get-Content $logFile -Raw
    $passed = ($logContent -match "\[RESULT\] ALL TESTS PASSED") -and ($LASTEXITCODE -eq 0)

    if ($passed) {
        Write-Host "[PASS] $($tb.Name) passed all checks!" -ForegroundColor Green
        $results += [PSCustomObject]@{
            Testbench = $tb.Module
            SuiteName = $tb.Name
            Status = "PASSED"
        }
    } else {
        Write-Host "[FAIL] $($tb.Name) failed verification!" -ForegroundColor Red
        $allPassed = $false
        $results += [PSCustomObject]@{
            Testbench = $tb.Module
            SuiteName = $tb.Name
            Status = "FAILED"
        }
    }
}

$EndTime = Get-Date
$Duration = ($EndTime - $StartTime).TotalSeconds

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                REGRESSION SUMMARY REPORT                 " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host "Total Execution Time: $([math]::Round($Duration, 2)) seconds" -ForegroundColor Gray

if ($allPassed) {
    Write-Host "[FINAL RESULT] ALL TESTBENCHES PASSED (100% SUCCESS)" -ForegroundColor Green
} else {
    Write-Host "[FINAL RESULT] SOME TESTBENCHES FAILED" -ForegroundColor Red
    exit 1
}
