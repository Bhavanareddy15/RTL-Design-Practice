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

## Bugs found along the way

- **`OUTPUT_WIDTH` is one bit too narrow.** `$clog2(8) = 3`, so `binary` is
  declared `[3:0]` (4 bits) but the index only needs 3 bits (0–7). The port
  declaration `output reg [OUTPUT_WIDTH:0]` adds an extra bit. Harmless for
  correctness but inconsistent — worth revisiting.

## Next experiments

- [ ] Synthesize and check cell count / logic depth vs. a casez-based version.
- [ ] Add a second output for the lowest set bit (dual-priority encoder).
- [ ] Parameterise the priority direction (highest vs. lowest wins).
