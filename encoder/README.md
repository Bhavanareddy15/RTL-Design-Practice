# Priority encoder

An 8-input priority encoder: takes a one-hot or multi-hot input and outputs
the binary index of the **highest set bit** plus a `valid` flag.

## Layout

| Path | Contents |
|------|----------|
| `rtl/encoder.sv` | parameterised priority encoder (default: 8 inputs → 3-bit index) |
| `tb/tb_encoder.sv` | self-checking testbench (9 directed cases) |
| `synth/stat_encoder.txt` | committed Yosys `stat` + logic depth |
| `build/` | generated: sim binary, VCD, netlist, schematic (gitignored) |

Run `make` for sim + synth, `make sim` / `make synth` individually,
`make lint` for Verilator lint.

---

## Design

```
inp[INPUT_WIDTH-1:0]  →  binary[OUTPUT_WIDTH:0]   (index of highest set bit)
                      →  valid                     (0 when inp == 0)
```

Parameters: `INPUT_WIDTH` (default 8), `OUTPUT_WIDTH` auto-derived as
`$clog2(INPUT_WIDTH)`.

The loop scans from bit 0 to bit `INPUT_WIDTH-1`, so the last write wins —
the highest-indexed set bit determines the output.

## Synthesis results (Yosys 0.58, generic target)

`synth/stat_encoder.txt` — full output committed.

### v1 — for-loop, `valid` inside the loop

| Metric | Value |
|---|---|
| Total cells | 21 |
| `$_OR_` | 15 |
| `$_ANDNOT_` | 4 |
| `$_NOR_` | 2 |
| Flip-flops / latches | 0 |
| Logic depth (LTP) | **7 gate levels** |
| Critical path endpoint | `valid` (via `inp[1]`) |

### v2 — `assign valid = |inp` extracted; output width fixed

| Metric | v1 | v2 | Δ |
|---|---|---|---|
| Total cells | 21 | **14** | −7 |
| `$_OR_` | 15 | 8 | −7 |
| `$_ANDNOT_` | 4 | 4 | 0 |
| `$_NOR_` | 2 | 2 | 0 |
| Logic depth (LTP) | 7 | **6** | −1 |
| Critical path endpoint | `valid` | `binary[0]` | shifted |
| Port bits | 13 | 12 | −1 |

### Observations

**`valid` was the critical-path endpoint in v1, not `binary`.**
Even though `valid` is conceptually just `|inp` (which needs only log₂(8) = 3
OR levels), it was embedded inside the priority mux chain. Yosys had to carry
the selection logic all the way through the chain before committing `valid`,
landing at depth 7. Extracting it as `assign valid = |inp` (v2) moved the
critical path to `binary[0]` at depth 6 and dropped 7 OR gates.

**`valid` must be declared `wire`, not `reg`, when driven by `assign`.**
The first extraction attempt left `output reg valid` in the port list while
driving it with a continuous assignment — Yosys warned about a `reg` on a
continuous assignment and implicitly resolved the multi-driver. The fix is to
declare it `output wire valid`; `binary` stays `output reg` because it is
driven from the `always` block.

**Yosys's WREDUCE pass exposed the output-width bug.**
At step 2.9 the tool pruned the top 3 bits of the intermediate mux and, later
via OPT_REDUCE, stripped `binary[3]` from all six mux stages — confirming it
is always 0. This was a direct consequence of the `[OUTPUT_WIDTH:0]`
declaration adding a dead bit. Fixed in v2 to `[OUTPUT_WIDTH-1:0]`.

**No latches were inferred.**
The `always @(*)` block drives `binary` in all branches (`binary = 0` at the
top handles the all-zeros default). `valid` is now a pure wire.

**ABC restructured the mux chain into OR / ANDNOT gates.**
The 8-mux priority chain was collapsed by ABC into OR and ANDNOT cells —
a more gate-efficient form — but depth stays near-linear because the priority
constraint forces sequential dependency between stages.

### v3 — casez-equivalent: scan-down with `found` flag (`rtl/encoder_casez.sv`)

A literal `casez` with `?` wildcards cannot be parameterized (case-item widths
must be compile-time literals, and Yosys does not support `break` in for-loops
as a portable early-exit).  The parameterized substitute scans MSB-first with a
`found` guard flag that blocks lower-priority bits from overwriting `binary`.

| Metric | v2 (scan-up) | v3 (casez-equiv) | Δ |
|---|---|---|---|
| Total cells | **14** | 38 | +24 |
| Logic depth | **6** | 8 | +2 |

**The casez-equivalent is worse, not better.**
The `found` flag creates a serial dependency across loop iterations — each
iteration's condition (`inp[i] && !found`) depends on all higher iterations'
results.  ABC cannot shorten that chain.  The simpler scan-up "last-write-wins"
loop exposes no such inter-iteration dependency, giving the optimizer full
freedom to restructure into an efficient tree.

Key takeaway: over-specifying priority intent in RTL (explicit guard) can
*hurt* QoR.  A literal `casez` (fixed N) would avoid the chain problem by
expressing priority through pattern matching rather than accumulated state —
but it sacrifices parameterizability.

### v4 — literal casez, fixed N=8 (`rtl/encoder_casez_fixed.sv`)

Non-parameterized `casez` with explicit `?`-wildcard patterns — no serial
`found` dependency.  Written to test whether removing the chain alone recovers
the QoR of v2.

| Metric | v2 (scan-up) | v3 (found-flag) | v4 (literal casez) |
|---|---|---|---|
| Total cells | **14** | 38 | 39 |
| `$_OR_` | 8 | 16 | 19 |
| `$_ANDNOT_` | 4 | 12 | 12 |
| Logic depth | **6** | 8 | 7 |

**The literal casez is also worse than v2, despite having no serial dependency.**
All three versions compute the same Boolean function, so the difference is
not logical — it is about what structure ABC receives as its starting point.

Before ABC runs, Yosys's pre-passes (WREDUCE, OPT_REDUCE) strip the dead MSB
from the scan-up mux chain and consolidate six mux cells, handing ABC a much
simpler 14-node network.  The `casez` and `found-flag` structures do not
trigger those same simplifications, so ABC starts from ~39 nodes and its
heuristic rewriting converges to a worse local optimum.

Core lesson: **synthesis optimization is heuristic, not exhaustive.**  The
same function can land at very different cell counts and depths depending on
the RTL style, because the pre-ABC passes shape the network that ABC starts
from, and ABC does not always find the global minimum from every starting
point.  Simpler, less explicit RTL often gives Yosys's early passes more
traction and results in better final QoR.

## Bugs found along the way

- **`OUTPUT_WIDTH` is one bit too narrow.** `$clog2(8) = 3`, so `binary` is
  declared `[3:0]` (4 bits) but the index only needs 3 bits (0–7). The port
  declaration `output reg [OUTPUT_WIDTH:0]` adds an extra bit. Harmless for
  correctness but inconsistent — Yosys's WREDUCE/OPT_REDUCE passess prune the
  dead MSB during synthesis, confirming it is never driven to 1.

## Next experiments

- [x] Synthesize and check cell count / logic depth (done — see above).
- [x] Implement casez-equivalent version and compare (done — see below).
- [x] Extract `valid = |inp` separately and measure depth reduction (−7 OR cells, depth 7→6).
- [ ] Add a second output for the lowest set bit (dual-priority encoder).
- [ ] Parameterise the priority direction (highest vs. lowest wins).
