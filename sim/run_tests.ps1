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

$compileCmd = "vlog -timescale 1ns/1ps -work work -sv macro_models/rom_512x16A.v macro_models/ram_128x16A.v rtl/adder.v rtl/alu.v rtl/alu_control.v rtl/clk_div.v rtl/control_unit.v rtl/cu.v rtl/data_mem.v rtl/imm_ext.v rtl/instr_mem.v rtl/mux.v rtl/pc.v rtl/reg_file.v rtl/uart_tx.v rtl/uart_rx.v rtl/uart_regs.v rtl/pwm_regs.v rtl/spi_reg.v rtl/virtual_temp_sensor.v rtl/virtual_fan.v rtl/risc_v.v tb/risc_v_isa_tb.v tb/uart_edge_tb.v tb/risc_v_uart_tb.v tb/uart_loopback_tb.v tb/risc_v_uart_full_tb.v tb/risc_v_hex_tb.v functional_test/risc_v_temp_pwm_tb.v +incdir+tb/layered tb/layered/rv_if.sv tb/layered/rv_layered_pkg.sv tb/layered/rv_layered_tb.sv"
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
    @{ Name = "RISC-V Hex-Loader SoC Test"; Module = "risc_v_hex_tb"; Args = "+HEX=assembly_codes/full_soc_test.hex"; Desc = "Dynamic loading and execution of full_soc_test.hex" },
    @{ Name = "Closed-Loop Thermal PWM & Telemetry"; Module = "risc_v_temp_pwm_tb"; Args = "+HEX=functional_test/pwm_temp_control.hex"; Desc = "SPI sensor querying, PWM fan regulation (80%->40%->80%), and UART ASCII telemetry" },
    @{ Name = "Layered TB: ALU Arithmetic & Logic"; Module = "rv_layered_tb"; Args = "+TEST=alu_test"; Desc = "Layered testbench verifying ALU & immediate operations (17 regs, 6 mem words)" },
    @{ Name = "Layered TB: Data Memory Access"; Module = "rv_layered_tb"; Args = "+TEST=mem_test"; Desc = "Layered testbench verifying RAM load/store & data integrity (9 regs, 5 mem words)" },
    @{ Name = "Layered TB: Branches & Loops"; Module = "rv_layered_tb"; Args = "+TEST=branch_test"; Desc = "Layered testbench verifying BEQ/BNE forward/backward branches (6 regs, 2 mem words)" },
    @{ Name = "Layered TB: UART Serial TX"; Module = "rv_layered_tb"; Args = "+TEST=uart_test"; Desc = "Layered testbench verifying MMIO UART serial output stream ('Hello, RISC-V!')" },
    @{ Name = "Layered TB: Full SoC Integration"; Module = "rv_layered_tb"; Args = "+TEST=full_soc_test"; Desc = "Layered testbench verifying CPU computation + RAM + UART report ('OK')" },
    @{ Name = "Layered TB: SPI & Temp Sensor"; Module = "rv_layered_tb"; Args = "+TEST=spi_temp_test"; Desc = "Layered testbench verifying SPI Master, Virtual Temp Sensor, PWM MMIO, and UART report" },
    @{ Name = "Layered TB: Virtual Fan & Tachometer"; Module = "rv_layered_tb"; Args = "+TEST=fan_test"; Desc = "Layered testbench verifying Virtual Fan spin-up, speed throttling (80%->40%), tachometer periods (1250, 2500), and UART report" },
    @{ Name = "Layered TB: Dynamic Temp Sensor"; Module = "rv_layered_tb"; Args = "+TEST=temp_sensor_test"; Desc = "Layered testbench verifying Virtual Temp Sensor multi-temperature dynamic reads (25C->75C), SPI Master, and UART report" }
)

$results = @()
$allPassed = $true

foreach ($tb in $testbenches) {
    Write-Host "`n----------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Running: $($tb.Name) ($($tb.Module))" -ForegroundColor Cyan
    Write-Host "Description: $($tb.Desc)" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray

    $testTag = if ($tb.Args -match "\+TEST=(\w+)") { $matches[1] } else { $tb.Module }
    $logFile = "${testTag}_sim.log"
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
