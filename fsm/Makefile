# FSM designs and their variants
#   make sim       - run each variant against its testbench (Icarus)
#   make synth     - synthesize every variant with Yosys, write stats + netlists
#   make compare   - print a cell-count summary of all variants
#   make equiv     - formally check each v1 == its one-hot v2 (Yosys miter + SAT)
#   make lint      - Verilator lint (needs verilator on PATH)
#   make clean
# Single targets also work, e.g. make sim-pattern_detector_onehot

# Each design: v1 is <design>.sv, v2 is <design>_onehot.sv
DESIGNS  := fsm_design pattern_detector
VARIANTS := $(foreach d,$(DESIGNS),$(d) $(d)_onehot)

# Testbench used for each design (shared by its variants)
TB_fsm_design       := tb/fsm_tb.sv
TB_pattern_detector := tb/tb_pattern_detector.sv
tb_for = $(TB_$(patsubst %_onehot,%,$(1)))

# Bounded equivalence depth (cycles after reset)
EQUIV_DEPTH := 25

BUILD    := build

# Use native yosys if installed, otherwise the YoWASP build (pip install yowasp-yosys).
# Note: YoWASP can only see files under the current directory, so keep paths relative.
YOSYS ?= $(shell command -v yosys 2>/dev/null || echo yowasp-yosys)

.PHONY: all sim synth compare equiv lint clean
all: sim synth compare

$(BUILD):
	mkdir -p $(BUILD)

# ---------------- simulation ----------------
sim: $(addprefix sim-,$(VARIANTS))

sim-%: rtl/%.sv | $(BUILD)
	iverilog -g2012 -DDUT=$* -o $(BUILD)/sim_$*.out $(call tb_for,$*) $<
	vvp $(BUILD)/sim_$*.out +vcd=$(BUILD)/$*.vcd > $(BUILD)/sim_$*.log
	@tail -n 2 $(BUILD)/sim_$*.log
	@grep -q "PASSED" $(BUILD)/sim_$*.log

# ---------------- synthesis ----------------
synth: $(addprefix synth-,$(VARIANTS))

synth-%: rtl/%.sv | $(BUILD)
	$(YOSYS) -q -l $(BUILD)/synth_$*.log -p "\
	  read_verilog -sv $<; \
	  synth -top $*; \
	  tee -o synth/stat_$*.txt stat; \
	  tee -a synth/stat_$*.txt ltp -noff; \
	  write_verilog -noattr $(BUILD)/netlist_$*.v; \
	  show -format dot -prefix $(BUILD)/schematic_$* $*"

compare: synth
	@for v in $(VARIANTS); do \
	  echo "== $$v"; \
	  grep -E '^ +[0-9]+ +(cells|\$$_)' synth/stat_$$v.txt; \
	  grep -E 'Longest' synth/stat_$$v.txt; \
	done

# ---------------- formal equivalence ----------------
# Both designs start in reset (areset_n=0 in step 1); the miter asserts the
# outputs match on every cycle after that, checked to a bounded depth.
equiv: $(addprefix equiv-,$(DESIGNS))

equiv-%: rtl/%.sv rtl/%_onehot.sv | $(BUILD)
	$(YOSYS) -q -l $(BUILD)/equiv_$*.log -p "\
	  read_verilog -sv $^; \
	  proc; opt_clean; async2sync; \
	  miter -equiv -flatten -make_assert $* $*_onehot miter; \
	  hierarchy -top miter; \
	  sat -verify -seq $(EQUIV_DEPTH) -set-at 1 in_areset_n 0 -prove-asserts -show-inputs miter"
	@echo "$*: equivalence check PASSED ($(EQUIV_DEPTH) cycles from reset)"

# ---------------- lint ----------------
lint:
	@for v in $(VARIANTS); do verilator --lint-only -Wall rtl/$$v.sv || exit 1; done

clean:
	rm -rf $(BUILD) obj_dir
