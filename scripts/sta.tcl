# Static timing + power analysis of a liberty-mapped netlist with OpenSTA.
# Driven by environment variables (see scripts/sta.sh):
#   LIB      liberty file          NETLIST   mapped Verilog netlist
#   TOP      top module            PERIOD    clock period in ns
#   ACTIVITY (optional) Tcl file of set_power_activity commands, e.g. from
#            scripts/vcd_toggles.py --sta-activity
#
# Assumptions (single-clock block in isolation):
#   - inputs arrive right at the clock edge (input delay 0), driven by a buf_1
#   - outputs are captured at the next edge (output delay 0), loaded by 5 fF
#   - no wire load (pre-placement), ideal clock (no clock tree yet)
#   - async reset is not timed (false path): it is assumed to come from a reset
#     synchronizer. Releasing it right at the clock edge, as input delay 0
#     would imply, fails the flops' removal check.

read_liberty $::env(LIB)
read_verilog $::env(NETLIST)
link_design  $::env(TOP)

create_clock -name clk -period $::env(PERIOD) [get_ports clk]

# (OpenSTA 2.3 has no `all_inputs -no_clocks`, so drop clk by hand)
set data_inputs {}
foreach port [all_inputs] {
    if {[get_full_name $port] ne "clk"} { lappend data_inputs $port }
}
set_input_delay  0 -clock clk $data_inputs
set_output_delay 0 -clock clk [all_outputs]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_1 $data_inputs
set_load 0.005 [all_outputs]
set_false_path -from [get_ports areset_n]

puts "\n=================== critical path (setup) ==================="
report_checks -path_delay max -fields {slew cap input_pins} -digits 3

puts "\n=================== hold check ==================="
report_checks -path_delay min -digits 3

puts "\n=================== timing summary ==================="
report_wns -digits 3
report_tns -digits 3
report_clock_min_period

puts "\n=================== power: with switching activity ==================="
# Activity is set on the inputs only; OpenSTA propagates it through the logic
# and flops (it ignores annotations on flop outputs).
if {[info exists ::env(ACTIVITY)] && $::env(ACTIVITY) ne ""} {
    puts "switching activity: measured, from $::env(ACTIVITY)"
    source $::env(ACTIVITY)
} else {
    puts "switching activity: assumed 0.1 toggles/cycle on every input"
    set_power_activity -global -activity 0.1 -duty 0.5
}
report_power -digits 6

puts "\n=================== power: clock only ==================="
# Data held still: what's left is the clock toggling the flops' internal clock
# circuitry, plus leakage. This is paid every cycle whatever the data does.
# (Runs last: in OpenSTA 2.3 a global activity overrides input activities.)
set_power_activity -global -activity 0.0 -duty 0.5
report_power -digits 6
