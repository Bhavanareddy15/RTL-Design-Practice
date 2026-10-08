# Priority encoder
#   make      - sim + synth
#   make sim  - compile and run the testbench (Icarus)
#   make synth - synthesize with Yosys, write stats + netlist
#   make lint  - Verilator lint
#   make clean

MODULE := encoder
BUILD  := build

YOSYS ?= $(shell command -v yosys 2>/dev/null || echo yowasp-yosys)

.PHONY: all sim synth lint clean
all: sim synth

$(BUILD):
	mkdir -p $(BUILD)

# ---------------- simulation ----------------
sim: rtl/$(MODULE).sv tb/tb_$(MODULE).sv | $(BUILD)
	iverilog -g2012 -o $(BUILD)/sim_$(MODULE).out tb/tb_$(MODULE).sv rtl/$(MODULE).sv
	vvp $(BUILD)/sim_$(MODULE).out +vcd=$(BUILD)/$(MODULE).vcd > $(BUILD)/sim_$(MODULE).log
	@tail -n 2 $(BUILD)/sim_$(MODULE).log
	@grep -q "ALL TESTS PASSED" $(BUILD)/sim_$(MODULE).log

# ---------------- synthesis ----------------
synth: rtl/$(MODULE).sv | $(BUILD)
	$(YOSYS) -q -l $(BUILD)/synth_$(MODULE).log -p "\
	  read_verilog -sv $<; \
	  synth -top $(MODULE); \
	  tee -o synth/stat_$(MODULE).txt stat; \
	  tee -a synth/stat_$(MODULE).txt ltp -noff; \
	  write_verilog -noattr $(BUILD)/netlist_$(MODULE).v; \
	  show -format dot -prefix $(BUILD)/schematic_$(MODULE) $(MODULE)"

# ---------------- lint ----------------
lint:
	verilator --lint-only -Wall rtl/$(MODULE).sv

clean:
	rm -rf $(BUILD) obj_dir
