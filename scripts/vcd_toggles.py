#!/usr/bin/env python3
"""Count signal toggles in a VCD as a proxy for dynamic power.

Dynamic power ~ alpha * C * V^2 * f. With V and f fixed, comparing RTL variants
comes down to switching activity (alpha) on each net. This counts per-bit 0<->1
transitions for every signal under a scope (default: the DUT instance).

Transitions to/from x/z and the initial value are not counted. Nets that are
aliases of each other (same VCD id) are counted once in the totals.

Usage:
    vcd_toggles.py <file.vcd> [--scope dut] [--clock clk] [--inputs areset_n,in]
                   [--summary-only]
"""
import argparse
import sys


def parse_vcd(path, scope_name):
    """Return ({id: [names]}, {id: width}, {id: toggles}, clock_edges_by_id)."""
    names = {}       # id -> list of signal names inside the scope
    widths = {}
    toggles = {}
    last = {}        # id -> last known value string (MSB first, padded)
    scope = []
    in_scope_depth = None

    with open(path) as f:
        for line in f:
            tok = line.split()
            if not tok:
                continue
            head = tok[0]

            if head == "$scope":
                scope.append(tok[2])
                if in_scope_depth is None and tok[2] == scope_name:
                    in_scope_depth = len(scope)
                continue
            if head == "$upscope":
                if in_scope_depth is not None and len(scope) == in_scope_depth:
                    in_scope_depth = None
                scope.pop()
                continue
            if head == "$var":
                if in_scope_depth is not None:
                    width, ident, name = int(tok[2]), tok[3], tok[4]
                    names.setdefault(ident, []).append(name)
                    widths[ident] = width
                    toggles.setdefault(ident, 0)
                continue
            if head.startswith("$") or head.startswith("#"):
                continue

            # Value change: scalar "0!" or vector "b0101 !"
            if head[0] in "bB":
                value, ident = head[1:], tok[1]
            elif head[0] in "01xzXZ":
                value, ident = head[0], head[1:]
            else:
                continue  # real values etc.
            if ident not in names:
                continue

            w = widths[ident]
            # VCD left-extends with 0 (or x/z if the MSB given is x/z)
            pad = value[0] if value[0] in "xzXZ" else "0"
            value = value.rjust(w, pad)[-w:]
            prev = last.get(ident)
            if prev is not None:
                toggles[ident] += sum(
                    1 for a, b in zip(prev, value) if a != b and a in "01" and b in "01"
                )
            last[ident] = value

    return names, widths, toggles


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("vcd")
    ap.add_argument("--scope", default="dut", help="instance whose signals are counted")
    ap.add_argument("--clock", default="clk", help="clock signal (reported separately)")
    ap.add_argument("--inputs", default="areset_n,in",
                    help="comma-separated inputs, excluded from the internal total")
    ap.add_argument("--summary-only", action="store_true")
    args = ap.parse_args()

    names, widths, toggles = parse_vcd(args.vcd, args.scope)
    if not names:
        sys.exit(f"no signals found under scope '{args.scope}' in {args.vcd}")

    inputs = set(filter(None, args.inputs.split(",")))
    clock_ids = {i for i, n in names.items() if args.clock in n}
    input_ids = {i for i, n in names.items() if inputs & set(n)} - clock_ids
    internal_ids = set(names) - clock_ids - input_ids

    if not args.summary_only:
        print(f"{'signal':32s} {'bits':>4s} {'toggles':>8s}")
        for ident in sorted(names, key=lambda i: (-toggles[i], names[i][0])):
            label = " = ".join(names[ident])
            print(f"{label:32.32s} {widths[ident]:4d} {toggles[ident]:8d}")
        print()

    clock_edges = sum(toggles[i] for i in clock_ids)
    print(f"clock toggles      : {clock_edges}  ({clock_edges // 2} cycles)")
    print(f"input toggles      : {sum(toggles[i] for i in input_ids)}")
    print(f"internal nets      : {sum(widths[i] for i in internal_ids)} bits")
    print(f"internal toggles   : {sum(toggles[i] for i in internal_ids)}")


if __name__ == "__main__":
    main()
