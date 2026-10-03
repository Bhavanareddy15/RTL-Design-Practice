# FSM — two-state toggle machine

## Spec

![state diagram](docs/state_diagram.png)

- Moore FSM, two states **A** and **B**, async active-low reset to **B**.
- `in = 1` → stay in current state; `in = 0` → toggle.
- `out = 1` in **B**, `0` in **A**.

## Layout

| Path | Contents |
|------|----------|
| `rtl/fsm_design.sv` | v1 — binary encoding (enum) |
| `rtl/fsm_design_onehot.sv` | v2 — hand-coded one-hot encoding |
| `tb/fsm_tb.sv` | self-checking TB with reference model; DUT picked by `-DDUT=<module>` |
| `synth/stat_*.txt` | committed Yosys `stat` + logic depth per variant |
| `build/` | generated: sim binaries, VCDs, netlists, logs, `.dot` schematics (gitignored) |

Run `make` for sim + synth + compare, and `make equiv` for formal equivalence.

## Variants

| | v1 binary | v2 one-hot |
|---|---|---|
| State flops | 1 (`$_DFF_PN1_`) | 2 (`$_DFF_PN0_`, `$_DFF_PN1_`) |
| Comb cells | 1 `$_XNOR_` | 2 `$_MUX_` |
| **Total cells** | **2** | **4** |
| Logic depth | 1 | 1 |
| Output decode | `out = state` (free: enum encodes B as 1) | `out = state[B]` (free) |
| Sim (223 checks) | pass | pass |
| Equivalent to v1 | — | yes, `make equiv` (bounded, 20 cycles from reset) |

Yosys generic `synth`, Yosys 0.58.

## Observations

- **One-hot is worse here.** One-hot pays off when it removes wide state
  decoding (many states, many outputs decoded from state). With 2 states binary
  is already 1 bit, so one-hot just adds a flop and doubles the next-state logic.
- **v1 collapses to `next = state XNOR in`.** `in ? state : ~state` is exactly XNOR.
- **v2 next-state bits become muxes.** `(state[B] & in) | (state[A] & ~in)`
  is `in ? state[B] : state[A]`, which Yosys maps to a single `$_MUX_`.
- **Power.** v2 has 2 flops on the clock instead of 1 (more clock load), and
  *both* flops toggle on every state change, while v1 toggles one.
- **Robustness.** v2 has 2 illegal states (`00`, `11`) that it can never leave;
  v1 has no illegal states at all.
- **Yosys did not re-encode v1.** `FSM_DETECT` found no FSM (the state register
  drives the output directly), so the encoding we wrote is what got built.

## Bug found along the way

The original v1 used `typedef enum {A, B} state_t;`. With no base type the enum
is a 32-bit `int`, so `case(state)` covering only `A` and `B` is incomplete and
Yosys errors out with *"Latch inferred for signal next_state"*. Fixed with
`typedef enum logic {A, B}`. Icarus simulated the original fine; only
synthesis exposed it. **Always give enums an explicit base type.**

## Next experiments

- [ ] Measure toggle counts from the VCDs to put numbers on the power claim.
- [ ] Map to a real liberty file (e.g. sky130) with `dfflibmap` + `abc -liberty`
      to compare area in µm² instead of generic cell count.
- [ ] Apply the same v1/v2 comparison to `pattern_detector` (7 states), where
      one-hot should start to win on decode logic.
- [ ] Try Yosys `(* fsm_encoding = "one-hot" *)` on the enum and compare with the hand-coded v2.
- [ ] Make the equivalence check unbounded (`sat -tempinduct`, or SymbiYosys).
