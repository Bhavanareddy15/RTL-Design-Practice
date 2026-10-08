#!/usr/bin/env bash
# Run OpenSTA on a mapped netlist at one corner.
#   sta.sh <lib> <netlist> <top> <period_ns> <corner> [activity.tcl]
# Optional env: SETUP_UNCERTAINTY, HOLD_UNCERTAINTY (ns, default 0.1 / 0.05).
# The standalone `sta` binary ships with the OpenROAD package in the
# micromamba env "eda" (micromamba create -n eda -c litex-hub -c conda-forge openroad);
# override with STA_BIN=/path/to/sta.
set -euo pipefail

export LIB=$1 NETLIST=$2 TOP=$3 PERIOD=$4 CORNER=$5 ACTIVITY=${6:-}
export SETUP_UNCERTAINTY=${SETUP_UNCERTAINTY:-0.1}
export HOLD_UNCERTAINTY=${HOLD_UNCERTAINTY:-0.05}
STA_BIN=${STA_BIN:-$HOME/micromamba/envs/eda/bin/sta}

exec "$STA_BIN" -no_init -no_splash -exit "$(dirname "$0")/sta.tcl"
