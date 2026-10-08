# FSM designs and their variants
#   make sim       - run each variant against its testbench (Icarus)
#   make synth     - synthesize every variant with Yosys, write stats + netlists
#   make compare   - print a cell-count summary of all variants
#   make equiv     - formally check each v1 == its one-hot v2 (Yosys miter + SAT)
#   make gls       - gate-level sim: run each TB against its Yosys netlist
#   make toggles   - count signal toggles (RTL + gate-level) as a power proxy
#   make timing    - map to sky130, run OpenSTA at ss/tt/ff: area, timing, power, closure
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
TOGGLES  := python ../scripts/vcd_toggles.py

# sky130 high-density standard cells. Map at the typical corner, then check
# timing at all three: slow (worst for setup), typical, fast (worst for hold).
LIB_DIR  := ../lib
LIB_URL  := https://raw.githubusercontent.com/efabless/skywater-pdk-libs-sky130_fd_sc_hd/master/timing
CORNERS  := ss_100C_1v60 tt_025C_1v80 ff_n40C_1v95
MAP_CORNER := tt_025C_1v80
lib_for   = $(LIB_DIR)/sky130_fd_sc_hd__$(1).lib
LIB_NAME := sky130_fd_sc_hd__$(MAP_CORNER).lib
# Low-power isolation/retention cells are for power-gated designs; real flows mark them dont_use
DONT_USE := -dont_use *lpflow*
# Clock period for STA and power, in ns (10 ns = 100 MHz)
PERIOD   := 10
# Clock uncertainty in ns: stands in for clock-tree skew + jitter before a
# clock tree exists. Setup loses it from the period; hold must beat it.
SETUP_UNCERTAINTY := 0.1
HOLD_UNCERTAINTY  := 0.05
# OpenSTA runs under WSL on Windows, natively elsewhere (see scripts/sta.sh)
STA      := $(if $(shell command -v wsl.exe 2>/dev/null),wsl.exe -d Ubuntu --) \
            env SETUP_UNCERTAINTY=$(SETUP_UNCERTAINTY) HOLD_UNCERTAINTY=$(HOLD_UNCERTAINTY) \
            bash ../scripts/sta.sh

# Use native yosys if installed, otherwise the YoWASP build (pip install yowasp-yosys).
# Note: YoWASP can only see files under the current directory, so keep paths relative.
YOSYS ?= $(shell command -v yosys 2>/dev/null || echo yowasp-yosys)

.PHONY: all sim synth compare equiv gls toggles timing lint clean
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

# ---------------- gate-level sim + toggle counts ----------------
# The netlist is plain Verilog over Yosys generic cells, so Icarus can run it
# with the same TB. Zero-delay sim: no glitches, so toggles are a lower bound.
gls: $(addprefix gls-,$(VARIANTS))

gls-%: synth-% | $(BUILD)
	iverilog -g2012 -DDUT=$* -o $(BUILD)/gls_$*.out $(call tb_for,$*) $(BUILD)/netlist_$*.v
	vvp $(BUILD)/gls_$*.out +vcd=$(BUILD)/gls_$*.vcd > $(BUILD)/gls_$*.log
	@tail -n 1 $(BUILD)/gls_$*.log
	@grep -q "PASSED" $(BUILD)/gls_$*.log

toggles: $(addprefix toggles-,$(VARIANTS))

toggles-%: sim-% gls-%
	@echo "### RTL ($(BUILD)/$*.vcd)" > synth/toggles_$*.txt
	@$(TOGGLES) $(BUILD)/$*.vcd >> synth/toggles_$*.txt
	@echo "" >> synth/toggles_$*.txt
	@echo "### Gate-level ($(BUILD)/gls_$*.vcd)" >> synth/toggles_$*.txt
	@$(TOGGLES) $(BUILD)/gls_$*.vcd >> synth/toggles_$*.txt
	@echo "== $*"; grep -E "^###|internal toggles|cycles" synth/toggles_$*.txt

# ---------------- sky130 mapping + OpenSTA ----------------
$(LIB_DIR)/%.lib:
	mkdir -p $(dir $@)
	curl -sSfL -o $@ $(LIB_URL)/$*.lib

# Yosys runs from the repo root so YoWASP can see both fsm/ and lib/
map-%: rtl/%.sv $(call lib_for,$(MAP_CORNER)) | $(BUILD)
	cd .. && $(YOSYS) -q -l fsm/$(BUILD)/map_$*.log -p "\
	  read_verilog -sv fsm/$<; \
	  synth -top $*; \
	  dfflibmap -liberty lib/$(LIB_NAME) $(DONT_USE); \
	  abc -liberty lib/$(LIB_NAME) $(DONT_USE); \
	  opt_clean -purge; \
	  tee -q -o fsm/synth/area_$*.txt stat -liberty lib/$(LIB_NAME); \
	  write_verilog -noattr -noexpr -nohex -nodec fsm/$(BUILD)/sky130_$*.v"

# One report per variant with a section per corner, each ending in a
# CLOSURE PASS/FAIL line. Power (from the input activity measured in the RTL
# sim) is reported at the mapping corner only.
timing: $(addprefix timing-,$(VARIANTS))
	@echo; echo "== timing closure at $(PERIOD) ns"
	@for v in $(VARIANTS); do \
	  grep "^CLOSURE" synth/timing_$$v.txt | sed "s/^CLOSURE/  $$v:/"; \
	done

timing-%: map-% sim-% $(foreach c,$(CORNERS),$(call lib_for,$(c)))
	@$(TOGGLES) $(BUILD)/$*.vcd --summary-only --sta-activity $(BUILD)/act_$*.tcl > /dev/null
	@rm -f synth/timing_$*.txt
	@for c in $(CORNERS); do \
	  act=""; [ $$c = $(MAP_CORNER) ] && act=$(BUILD)/act_$*.tcl; \
	  $(STA) $(call lib_for,$$c) $(BUILD)/sky130_$*.v $* $(PERIOD) $$c $$act \
	    >> synth/timing_$*.txt || exit 1; \
	done
	@echo "== $*  ($$(grep -o "Chip area.*" synth/area_$*.txt))"
	@grep -E "^CLOSURE|period_min" synth/timing_$*.txt

# ---------------- lint ----------------
lint:
	@for v in $(VARIANTS); do verilator --lint-only -Wall rtl/$$v.sv || exit 1; done

clean:
	rm -rf $(BUILD) obj_dir
