# FSM design variants
#   make sim       - run the testbench against every variant (Icarus)
#   make synth     - synthesize every variant with Yosys, write stats + netlists
#   make compare   - print a cell-count summary of all variants
#   make equiv     - formally check v1 == v2 (Yosys miter + SAT)
#   make lint      - Verilator lint (needs verilator on PATH)
#   make clean

VARIANTS := fsm_design fsm_design_onehot
TB       := tb/fsm_tb.sv
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

sim-%: rtl/%.sv $(TB) | $(BUILD)
	iverilog -g2012 -DDUT=$* -o $(BUILD)/sim_$*.out $(TB) $<
	vvp $(BUILD)/sim_$*.out +vcd=$(BUILD)/$*.vcd | tee $(BUILD)/sim_$*.log
	@grep -q "TEST PASSED" $(BUILD)/sim_$*.log

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
equiv: | $(BUILD)
	$(YOSYS) -q -l $(BUILD)/equiv.log -p "\
	  read_verilog -sv rtl/fsm_design.sv rtl/fsm_design_onehot.sv; \
	  proc; opt_clean; async2sync; \
	  miter -equiv -flatten -make_assert fsm_design fsm_design_onehot miter; \
	  hierarchy -top miter; \
	  sat -verify -seq 20 -set-at 1 in_areset_n 0 -prove-asserts -show-inputs miter"
	@echo "equivalence check PASSED (20 cycles from reset)"

# ---------------- lint ----------------
lint:
	@for v in $(VARIANTS); do verilator --lint-only -Wall rtl/$$v.sv || exit 1; done

clean:
	rm -rf $(BUILD) obj_dir
