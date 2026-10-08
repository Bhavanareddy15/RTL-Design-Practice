# RTL Design Practice

A personal workspace for designing RTL modules, verifying them, and synthesizing
them to study **how RTL choices map to hardware** — and how to rewrite RTL to
save **area** and **power**.

## Goals

- Write clean, synthesizable SystemVerilog for common building blocks.
- Verify each block with a self-checking testbench (and formal where it pays off).
- Synthesize with Yosys and inspect cell counts, logic depth, and netlist structure.
- Try RTL variants of the same function and compare the results (area, depth,
  flop count, switching activity).
- Record what was learned so each experiment builds on the last.

## Toolchain

| Purpose        | Tool                                  |
|----------------|---------------------------------------|
| Simulation     | Icarus Verilog (`iverilog`/`vvp`), Verilator |
| Lint           | `verilator --lint-only -Wall`         |
| Waveforms      | GTKWave (`.vcd` / `.fst`)             |
| Synthesis      | Yosys (generic `synth`, optionally `abc` with a liberty file); `yowasp-yosys` works if native Yosys isn't installed |
| Formal         | SymbiYosys (`sby`) when needed        |
| Cell library   | SkyWater sky130 HD (`lib/`, downloaded on first use) |
| Timing / power | OpenSTA (from OpenROAD, via micromamba in WSL) — see [Setup](#setup-for-make-timing) below |

## Modules

| Module | Directory | Sim | Synth | Formal | Notes |
|--------|-----------|-----|-------|--------|-------|
| Encoder | [encoder/](encoder/) | ✅ | ⬜ | ⬜ | |
| FSM (v1 binary, v2 one-hot) | [fsm/](fsm/) | ✅ | ✅ | ✅ | equiv check; one-hot costs 2× cells — see [NOTES](fsm/NOTES.md) |
| Pattern detector (v1 binary, v2 one-hot) | [fsm/](fsm/) | ✅ | ✅ | ✅ | sky130: one-hot 6–8% faster but 56% larger, 88% more power; timing closed at 10 ns (ss/tt/ff) — see [NOTES](fsm/NOTES.md) |
| Shift register | [shift_register/](shift_register/) | ✅ | ⬜ | ⬜ | |
| Prepend packet | [prepend_packet/](prepend_packet/) | ✅ | ✅ | ⬜ | |
| Fixed-priority arbiter | [arbiters/](arbiters/) | ✅ | ⬜ | ⬜ | |
| Round-robin arbiter | [arbiters/](arbiters/) | ✅ | ⬜ | ⬜ | |

Legend: ✅ done · 🟡 in progress · ⬜ not started

## Typical flow

```sh
# Lint
verilator --lint-only -Wall <module>.sv

# Simulate (Icarus)
iverilog -g2012 -o sim_<module>.out tb_<module>.sv <module>.sv
vvp sim_<module>.out

# Synthesize (Yosys) and report stats
yosys -p "read_verilog -sv <module>.sv; synth -top <module>; stat; write_verilog -noattr synth_<module>.v"

# Formal (SymbiYosys)
sby -f <module>.sby
```

## What to look at after synthesis

- **Cell count / `stat`** – total cells, flops vs. combinational cells.
- **Logic depth** – `abc` / `ltp` output as a proxy for timing.
- **Flop count** – unexpected flops often mean an unintended latch or redundant state.
- **Muxes and adders** – check whether resource sharing happened.
- **Power proxies** – flop count, clock-enable/gating opportunities, toggle
  activity from simulation (VCD), and unnecessary resets on datapath registers.
  [`scripts/vcd_toggles.py`](scripts/vcd_toggles.py) counts toggles per net —
  see [Switching activity](#switching-activity) for the full methodology.

## Switching activity

Dynamic power ≈ α·C·V²·f. When comparing designs at the same V and f, the
difference is **how often each net switches (α)** and **how much capacitance
it drives (C)**. `make toggles` measures α:

1. The TB dumps a VCD: every value change of every signal, with timestamps.
2. `make gls` re-runs the same TB against the Yosys netlist, so the VCD also
   captures every internal gate output, not just the signals named in the RTL.
3. [`scripts/vcd_toggles.py`](scripts/vcd_toggles.py) counts per-bit 0↔1
   transitions for every net in the `dut` scope (ignoring the initial value
   and x/z), and separates clock, inputs and internal nets.
4. Compare designs with identical stimulus (same TB, same seed).

**Always measure at gate level.** RTL VCDs only see named signals; internal
decode/encode logic is invisible, so RTL counts can point the wrong way — a
design that looks worse at RTL may switch less at gate level because its logic
is simpler.

*Definitions:* Internal toggles = all DUT nets except `clk` and primary
inputs. Clock-pin toggles = flops × clock toggles (each flop's clock pin
switches every edge, even when its data doesn't change).

## Sky130 timing flow

`make timing` runs four steps on any design:

1. **Cell mapping.** Yosys `dfflibmap + abc -liberty` maps the netlist onto sky130
   HD standard cells. `stat -liberty` reports area in µm². Low-power `lpflow_*`
   cells are excluded (`dont_use`), as in real flows.
2. **Static timing analysis.** OpenSTA ([`scripts/sta.tcl`](scripts/sta.tcl))
   times every flop-to-flop path using library delay tables: clk→Q of the
   launching flop + combinational logic + setup of the capturing flop. Default
   constraints: inputs driven by `buf_1`, 5 fF output load, ideal clock,
   no wire parasitics (pre-placement), uncertainty 0.1 ns (setup) / 0.05 ns
   (hold). The same netlist is timed at three corners: slow (`ss`), typical
   (`tt`), fast (`ff`). Override any value:
   `make timing PERIOD=2 SETUP_UNCERTAINTY=0.2 HOLD_UNCERTAINTY=0.05`.
3. **Power** at a 10 ns clock (100 MHz), typical corner. Measured input activity
   (from the RTL VCD) is fed to OpenSTA, which propagates it through the logic.
   Reported twice: with that activity, and with all data held still (**clock
   only**), isolating the static cost of clocking the flops.
4. **Closure verdict** per corner — setup slack ≥ 0, hold slack ≥ 0, no DRC
   violations, no unconstrained endpoints.

Reports land in `synth/area_*.txt` and `synth/timing_*.txt` (one section per
corner).

## Timing closure

**Timing is closed at a corner when every check has non-negative slack, there
are no design-rule violations, and nothing is left unconstrained.** A design
is closed when that holds at every corner. Each corner's section of
`synth/timing_*.txt` ends with the evidence and a verdict:

| Check | OpenSTA call | Pass when |
|---|---|---|
| Setup: data arrives before the next edge (minus uncertainty) | `sta::worst_slack -max` | ≥ 0 |
| Hold: data stays stable after the edge (plus uncertainty) | `sta::worst_slack -min` | ≥ 0 |
| Design rules: max slew / capacitance / fanout from the library | `sta::max_*_violation_count` | 0 |
| Constraints complete: no unclocked flops, missing I/O delays | `check_setup` | returns 1 |

**Corners.** The same netlist is timed with three liberty files:

| Corner | Process / V / T | Cells are | Worst for |
|---|---|---|---|
| `ss_100C_1v60` | slow-slow, 1.60 V, 100 °C | slowest (~2× tt) | **setup** |
| `tt_025C_1v80` | typical, 1.80 V, 25 °C | nominal | — |
| `ff_n40C_1v95` | fast-fast, 1.95 V, −40 °C | fastest (~0.65× tt) | **hold** |

**Clock uncertainty** stands in for the clock tree that doesn't exist yet:
skew (the clock reaching flops at slightly different times) plus jitter. It
is subtracted from the period for setup and added to the requirement for hold.

- **One corner is not enough.** A design can pass at typical but fail at slow
  (setup) or fast (hold). Always check all three; a real 100 MHz sign-off
  quotes the slow corner.
- **The slow corner roughly halves fmax.** Plan for ~2× the typical-corner
  minimum period when targeting a slow sign-off corner.
- **Hold doesn't depend on the clock period**, only on how fast the shortest
  path is. Tighten hold uncertainty or insert buffers on short paths.

## Caveats (pre-layout timing and power)

- **Power is vectorless beyond the primary inputs.** OpenSTA 2.3 can't read a
  VCD, so internal activity is estimated by propagating input probability
  through the logic assuming signal independence. The clock-only power (all
  data held still) doesn't rely on this assumption and is the reliable number.
- **Pre-layout, so "closed" is provisional.** No wire capacitance, ideal clock
  with uncertainty instead of a real clock tree (whose buffers also add clock
  power). Real closure re-times after place and route with extracted parasitics.
  I/O delays of 0 are placeholders; in a real chip they come from surrounding
  blocks.
- **Hold margin depends on where inputs come from.** With input delay 0, the
  tightest hold paths start right at primary inputs. If a signal comes from a
  flop in another block, its clk→Q delay adds hold margin.

## Setup for `make timing`

- The liberty files (ss / tt / ff, ~13 MB each) are downloaded to `lib/` on
  first use from SkyWater's
  [sky130_fd_sc_hd repo](https://github.com/efabless/skywater-pdk-libs-sky130_fd_sc_hd)
  (gitignored).
- Knobs: `make timing PERIOD=2 SETUP_UNCERTAINTY=0.2 HOLD_UNCERTAINTY=0.05`.
- OpenSTA comes with OpenROAD from the litex-hub conda channel, installed in
  WSL Ubuntu with [micromamba](https://mamba.readthedocs.io) (no sudo):
  ```sh
  curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xj -C ~/.local bin/micromamba
  MAMBA_ROOT_PREFIX=~/micromamba ~/.local/bin/micromamba create -n eda -c litex-hub -c conda-forge openroad
  ```
  [`scripts/sta.sh`](scripts/sta.sh) runs `~/micromamba/envs/eda/bin/sta`
  (OpenSTA 2.3.1); override with `STA_BIN=...`.
