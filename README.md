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

## Modules

| Module | Directory | Sim | Synth | Formal | Notes |
|--------|-----------|-----|-------|--------|-------|
| Encoder | [encoder/](encoder/) | ✅ | ⬜ | ⬜ | |
| FSM (v1 binary, v2 one-hot) | [fsm/](fsm/) | ✅ | ✅ | ✅ | equiv check; one-hot costs 2× cells — see [NOTES](fsm/NOTES.md) |
| Pattern detector (v1 binary, v2 one-hot) | [fsm/](fsm/) | ✅ | ✅ | ✅ | one-hot wins: 21 vs 36 cells, depth 5 vs 7 — see [NOTES](fsm/NOTES.md) |
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
  [`scripts/vcd_toggles.py`](scripts/vcd_toggles.py) counts toggles per net; run
  it on a **gate-level** VCD (TB against the Yosys netlist), since RTL VCDs miss
  the internal logic — see [fsm/NOTES.md](fsm/NOTES.md) §3 for an example.
