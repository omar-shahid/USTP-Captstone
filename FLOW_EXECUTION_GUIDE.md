# Step-by-Step ASIC Execution Guide: RISC-V SoC with Hard Macros
## Technology: TSMC 0.18µm (CL018G 6-Metal) | EDA: Cadence Genus & Innovus

This guide details the exact sequence of commands and scripts required to take the single-cycle RISC-V SoC with UART MMIO and Artisan RAM/ROM hard macros from RTL through synthesis and physical design to GDSII layout.

---

## Directory Overview

```
D:\ic_design\RISC_V\
├── constraints/
│   └── constraints.sdc            # SDC timing & DRC constraints
├── synthesis/
│   ├── run_genus.tcl              # Genus synthesis script
│   └── output/                    # Generated netlist, SDF, reports
├── physical_design/
│   ├── mmmc_setup.tcl             # Multi-Mode Multi-Corner definition
│   ├── 01_init_design.tcl         # Step 1: Design import & LEF setup
│   ├── 02_floorplan.tcl           # Step 2: Floorplan & Macro placement
│   ├── 03_power_plan.tcl          # Step 3: VDD/VSS rings, stripes & sroute
│   ├── 04_placement.tcl           # Step 4: Standard cell placement
│   ├── 05_cts.tcl                 # Step 5: Clock tree synthesis (CCOpt)
│   ├── 06_route.tcl               # Step 6: NanoRoute & filler insertion
│   ├── 07_signoff.tcl             # Step 7: QRC extraction, DRC & signoff STA
│   ├── 08_export.tcl              # Step 8: GDSII, DEF, SDF, SPEF export
│   ├── run_innovus_full.tcl       # Master automation script (Steps 1–8)
│   ├── checkpoints/               # Saved design states (.enc) per step
│   ├── reports/                   # Timing, congestion, DRC, power reports
│   └── output/                    # Final tapeout deliverables
├── lef/
│   └── all.lef                    # TSMC 0.18um tech, cell & macro LEF
├── lib/
│   ├── slow.lib / fast.lib        # Standard cell timing libraries
│   ├── rom_512x16A_*_syn.lib      # 512x16 ROM macro timing
│   └── ram_128x16A_*_syn.lib      # 128x16 RAM macro timing
└── QRC/
    ├── t018s6mm.tch               # QRC parasitic extraction techfile
    ├── t018s6mm.CapTbl            # Capacitance table
    └── lefdef.layermap            # Stream-out GDSII layer map
```

---

## Step 0: RTL Functional Verification (ModelSim / QuestaSim)

Before running synthesis, verify that the RTL logic and macro simulation models pass all regression tests.

In PowerShell:
```powershell
cd D:\ic_design\RISC_V

# Run full automated regression suite (all 6 testbenches)
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1
```

**Expected Outcome**: `[FINAL RESULT] ALL TESTBENCHES PASSED (100% SUCCESS)`.

---

## Step 1: Logic Synthesis (Cadence Genus)

Synthesizes the behavioral RTL into a mapped gate-level netlist using the TSMC 0.18µm standard cells while keeping the RAM and ROM macros as hard black boxes.

In your terminal / EDA shell:
```bash
cd D:/ic_design/RISC_V
genus -f synthesis/run_genus.tcl
```

### What this script does:
1. Loads physical library rules: `lef/all.lef`
2. Loads timing libraries: `slow.lib`, `ram_128x16A_slow_syn.lib`, `rom_512x16A_slow_syn.lib`
3. Reads and elaborates RTL modules
4. Sets `dont_touch` on macro instances (`*rom_inst_*` and `*ram_data_*`)
5. Applies timing constraints from `constraints/constraints.sdc`
6. Runs optimization (`syn_generic` -> `syn_map` -> `syn_opt`)
7. Writes deliverables to `synthesis/output/`:
   - `risc_v_netlist.v` (Gate-level netlist for Innovus)
   - `risc_v_constraints.sdc` (Propagated constraints)
   - `risc_v.sdf` (Timing annotation)
   - Reports in `synthesis/output/reports/` (`timing_report.rpt`, `area_report.rpt`, `qor_report.rpt`)

### Quality Checks to Verify:
- [ ] No unresolved references in `check_design -unresolved`
- [ ] Worst Negative Slack (WNS) >= 0.00 ns in `timing_report.rpt`
- [ ] Hard macros instantiated as single leaf instances, not decomposed into gates

---

## Step 2: Physical Design (Cadence Innovus)

You have two execution methods:
- **Method A (Recommended)**: Interactive GUI step-by-step for visualization and learning.
- **Method B**: One-shot batch automated execution.

---

### Method A: Step-by-Step Interactive GUI Flow

Launch Innovus GUI:
```bash
cd D:/ic_design/RISC_V
innovus
```

Once the Innovus prompt (`innovus 1>`) appears, execute the following steps in sequence:

#### 2.1 — Initialize Design
```tcl
source physical_design/01_init_design.tcl
```
- **Action**: Loads gate-level netlist, `all.lef`, MMMC corner views (slow: 1.62V/125°C, fast: 1.98V/0°C), and connects VDD/VSS.
- **Inspect**: Design hierarchy browser displays `risc_v` top cell with child instances.
- **Checkpoint Saved**: `physical_design/checkpoints/01_init.enc`

#### 2.2 — Floorplanning & Macro Placement
```tcl
source physical_design/02_floorplan.tcl
```
- **Action**:
  - Creates die boundary (1500 µm × 1200 µm) with `SITE tsm3site` core rows
  - Places 2x RAM macros (`ram_data_lo`, `ram_data_hi`) along top edge
  - Places 2x ROM macros (`rom_inst_lo`, `rom_inst_hi`) along bottom edge
  - Adds 10 µm placement halos around each macro to reserve routing channels
  - Places I/O pins along perimeter (clk/reset/rx on Left, tx on Right, debug on Top/Bottom)
- **Inspect in GUI**: Click **Floorplan View** icon (`F`). Check that the 4 macro rectangles are placed cleanly with halos and standard cell rows in the center.
- **Checkpoint Saved**: `physical_design/checkpoints/02_floorplan.enc`

#### 2.3 — Power Planning (P/G Grid)
```tcl
source physical_design/03_power_plan.tcl
```
- **Action**:
  - Builds 10 µm core power rings on `Metal5` (Horizontal) and `Metal6` (Vertical)
  - Adds 4 µm block power rings around each RAM and ROM macro
  - Builds vertical (`Metal6`) and horizontal (`Metal5`) power stripes at 100 µm pitch
  - Runs `sroute` to connect standard cell rows (`Metal1`) and macro power pins
  - Runs connectivity check
- **Inspect in GUI**: Turn on power nets in the layer visibility panel. Verify that VDD (red) and VSS (blue) rings encircle the core and macros, and rails connect across all rows.
- **Reports**: Check `physical_design/reports/power_connectivity.rpt` (0 violations).
- **Checkpoint Saved**: `physical_design/checkpoints/03_power_plan.enc`

#### 2.4 — Standard Cell Placement
```tcl
source physical_design/04_placement.tcl
```
- **Action**:
  - Runs timing-driven global and detailed placement (`place_design -concurrent`)
  - Runs pre-CTS optimization (`opt_design -pre_cts`)
- **Inspect in GUI**: Click **Amoeba View** or **Physical View** (`P`). Standard cells now fill the central core region between the macros.
- **Reports to Check**:
  - `physical_design/reports/placement_check.rpt` (Verify: 0 overlapping instances)
  - `physical_design/reports/post_place_timing.rpt` (Verify setup slack)
- **Checkpoint Saved**: `physical_design/checkpoints/04_placement.enc`

#### 2.5 — Clock Tree Synthesis (CTS)
```tcl
source physical_design/05_cts.tcl
```
- **Action**:
  - Configures Artisan clock buffers (`CLKBUFX*`) and inverters (`CLKINVX*`)
  - Synthesizes clock trees for primary clock (`clk`, 50 MHz) and CPU clock (`clk_d`, 250 kHz)
  - Routes clock nets on `Metal3`–`Metal5`
  - Runs post-CTS setup and hold optimization (`opt_design -post_cts -hold`)
- **Inspect in GUI**: Open **Clock -> CCOpt Clock Tree Debugger** to visualize skew trees, insertion delays, and buffer insertion levels.
- **Reports to Check**:
  - `physical_design/reports/cts_skew_groups.rpt` (Skew target < 0.2 ns)
  - `physical_design/reports/post_cts_timing_hold.rpt` (Hold slack >= 0.00 ns)
- **Checkpoint Saved**: `physical_design/checkpoints/05_cts.enc`

#### 2.6 — Signal Routing
```tcl
source physical_design/06_route.tcl
```
- **Action**:
  - Runs NanoRoute detailed routing across `Metal1`–`Metal6`
  - Runs timing-driven and signal integrity (SI/crosstalk) optimization
  - Runs post-route optimization (`opt_design -post_route -hold`)
  - Runs ECO routing to eliminate any DRC violations
  - Inserts standard cell filler cells (`FILL64` down to `FILL1`) to guarantee N-well/P-substrate continuity
- **Inspect in GUI**: Toggle routing metal layers (`M1`–`M6`). Nets are now fully routed with vias.
- **Reports to Check**:
  - `physical_design/reports/post_route_drc.rpt` (Target: 0 DRC violations)
  - `physical_design/reports/route_summary.rpt` (Check completion rate: 100%)
- **Checkpoint Saved**: `physical_design/checkpoints/06_route.enc`

#### 2.7 — Signoff Verification
```tcl
source physical_design/07_signoff.tcl
```
- **Action**:
  - Performs signoff-grade RC extraction using QRC technology file (`t018s6mm.tch`)
  - Checks Setup timing at Slow Corner (1.62V, 125°C)
  - Checks Hold timing at Fast Corner (1.98V, 0°C)
  - Runs signoff Design Rule Check (`verify_drc`)
  - Runs signoff Connectivity / LVS (`verify_connectivity`)
  - Runs Process Antenna verification (`verify_process_antenna`)
  - Generates power dissipation reports
- **Reports to Review**:
  - `physical_design/reports/signoff_timing_summary.rpt`
  - `physical_design/reports/signoff_drc.rpt`
  - `physical_design/reports/signoff_connectivity.rpt`
  - `physical_design/reports/signoff_power_slow.rpt`
- **Checkpoint Saved**: `physical_design/checkpoints/07_signoff.enc`

#### 2.8 — Design Export & Deliverables
```tcl
source physical_design/08_export.tcl
```
- **Action**:
  - Exports GDSII layout stream (`risc_v.gds`) mapped via `QRC/lefdef.layermap`
  - Exports final post-route netlist (`risc_v_post_route.v`)
  - Exports back-annotation SDF timing files (`risc_v_slow.sdf`, `risc_v_fast.sdf`)
  - Exports DEF floorplan/routing geometry (`risc_v.def`)
  - Exports SPEF parasitic data (`risc_v.spef`)
  - Saves final session checkpoint (`08_final.enc`)
- **Output Location**: `physical_design/output/`

---

### Method B: Fully Automated One-Shot Batch Flow

If you want to run the entire physical design flow non-stop in batch mode:

```bash
cd D:/ic_design/RISC_V
innovus -files physical_design/run_innovus_full.tcl
```

This will automatically create all directories, execute Steps 1 through 8 in sequence, save checkpoints after each step, and output a runtime summary.

---

## Step 3: Resuming from Any Checkpoint

If you close Innovus and want to resume from a specific stage, start Innovus and restore the checkpoint:

```tcl
# Example: Resume from placed design
innovus
restoreDesign physical_design/checkpoints/04_placement.enc.dat risc_v

# Continue with CTS:
source physical_design/05_cts.tcl
```

---

## Summary of Generated Deliverables

| Deliverable | Path | Description |
|:---|:---|:---|
| **GDSII** | `physical_design/output/risc_v.gds` | Complete layout for mask/tapeout |
| **DEF** | `physical_design/output/risc_v.def` | Full physical design exchange file |
| **Post-Route Netlist** | `physical_design/output/risc_v_post_route.v` | Verilog netlist including CTS buffers & fillers |
| **SDF (Slow)** | `physical_design/output/risc_v_slow.sdf` | Worst-case setup timing for back-annotated simulation |
| **SDF (Fast)** | `physical_design/output/risc_v_fast.sdf` | Best-case hold timing for back-annotated simulation |
| **SPEF** | `physical_design/output/risc_v.spef` | Detailed parasitic R and C network |
