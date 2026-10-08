# Static timing (+ optional power) analysis of a liberty-mapped netlist with
# OpenSTA, ending in a timing-closure verdict for one corner.
# Driven by environment variables (see scripts/sta.sh):
#   LIB      liberty file of the corner   NETLIST   mapped Verilog netlist
#   TOP      top module                   PERIOD    clock period in ns
#   CORNER   corner name (for the report)
#   SETUP_UNCERTAINTY / HOLD_UNCERTAINTY  clock uncertainty in ns
#   ACTIVITY (optional) Tcl file of set_power_activity commands; when given,
#            power is reported too
#
# Assumptions (single-clock block in isolation):
#   - inputs arrive right at the clock edge (input delay 0), driven by a buf_1
#   - outputs are captured at the next edge (output delay 0), loaded by 5 fF
#   - no wire load (pre-placement), ideal clock: no clock tree yet, so clock
#     uncertainty stands in for its skew plus clock jitter
#   - async reset is not timed (false path): it is assumed to come from a reset
#     synchronizer. Releasing it right at the clock edge, as input delay 0
#     would imply, fails the flops' removal check.

read_liberty $::env(LIB)
read_verilog $::env(NETLIST)
link_design  $::env(TOP)

create_clock -name clk -period $::env(PERIOD) [get_ports clk]
set_clock_uncertainty -setup $::env(SETUP_UNCERTAINTY) [get_clocks clk]
set_clock_uncertainty -hold  $::env(HOLD_UNCERTAINTY)  [get_clocks clk]

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

puts "\n######################## corner $::env(CORNER) ########################"
puts "period $::env(PERIOD) ns, uncertainty setup $::env(SETUP_UNCERTAINTY) / hold $::env(HOLD_UNCERTAINTY) ns"

puts "\n=================== constraint check ==================="
# Returns 1 when clean; otherwise lists unclocked flops, missing I/O delays,
# unconstrained endpoints, combinational loops, ...
set constraints_ok [check_setup -verbose]

puts "\n=================== critical path (setup) ==================="
report_checks -path_delay max -fields {slew cap input_pins} -digits 3

puts "\n=================== critical path (hold) ==================="
report_checks -path_delay min -digits 3

puts "\n=================== design rule violations ==================="
report_check_types -max_slew -max_capacitance -max_fanout -violators

puts "\n=================== timing summary ==================="
report_clock_min_period

if {[info exists ::env(ACTIVITY)] && $::env(ACTIVITY) ne ""} {
    puts "\n=================== power: with switching activity ==================="
    # Activity is set on the inputs only; OpenSTA propagates it through the
    # logic and flops (it ignores annotations on flop outputs).
    puts "switching activity: measured, from $::env(ACTIVITY)"
    source $::env(ACTIVITY)
    report_power -digits 6

    puts "\n=================== power: clock only ==================="
    # Data held still: what's left is the clock toggling the flops' internal
    # clock circuitry, plus leakage. Paid every cycle whatever the data does.
    # (Runs last: in OpenSTA 2.3 a global activity overrides input activities.)
    set_power_activity -global -activity 0.0 -duty 0.5
    report_power -digits 6
}

# ---------------- closure verdict ----------------
# Timing is closed at this corner when every check has non-negative slack,
# there are no design-rule violations, and nothing is left unconstrained.
set setup_wns [sta::worst_slack -max]
set hold_wns  [sta::worst_slack -min]
set setup_tns [sta::total_negative_slack -max]
set hold_tns  [sta::total_negative_slack -min]
set drv [expr {[sta::max_slew_violation_count]
             + [sta::max_capacitance_violation_count]
             + [sta::max_fanout_violation_count]}]

set failures {}
if {$setup_wns < 0} { lappend failures "setup" }
if {$hold_wns  < 0} { lappend failures "hold" }
if {$drv > 0}       { lappend failures "design rules" }
if {!$constraints_ok} { lappend failures "constraints" }
set verdict [expr {[llength $failures] ? "FAIL ([join $failures {, }])" : "PASS"}]

puts "\n=================== closure ==================="
puts [format "setup WNS %7.3f ns  TNS %7.3f ns" $setup_wns $setup_tns]
puts [format "hold  WNS %7.3f ns  TNS %7.3f ns" $hold_wns $hold_tns]
puts "design rule violations: $drv"
puts "constraints complete:   [expr {$constraints_ok ? "yes" : "no"}]"
puts [format "CLOSURE %-14s %-28s setup %7.3f  hold %7.3f  ns" \
          $::env(CORNER) $verdict $setup_wns $hold_wns]
