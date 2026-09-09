set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_name gem2_j10b
set project_dir [file join $root_dir build vivado]
set reports_dir [file join $root_dir reports]
set artifacts_dir [file join $root_dir artifacts]

if {[info exists ::env(BOARD_REPO_PATHS)] && $::env(BOARD_REPO_PATHS) ne ""} {
    set_param board.repoPaths [split $::env(BOARD_REPO_PATHS) ":"]
}

file mkdir $project_dir
file mkdir $reports_dir
file mkdir $artifacts_dir

create_project $project_name $project_dir -part xck26-sfvc784-2LV-c -force
set_property board_part xilinx.com:kr260_som:part0:2.0 [current_project]
set_property board_connections {som240_1_connector xilinx.com:kr260_carrier:som240_1_connector:2.0 som240_2_connector xilinx.com:kr260_carrier:som240_2_connector:2.0} [current_project]
set_property target_language Verilog [current_project]
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

create_bd_design design_1
source [file join $script_dir create_block_design.tcl]

set bd_file [get_files -quiet design_1.bd]
set wrapper_files [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_files
set_property top design_1_wrapper [current_fileset]
add_files -fileset constrs_1 -norecurse [file join $root_dir constraints gem2_j10b.xdc]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}
open_run synth_1
report_utilization -file [file join $reports_dir utilization_synth.rpt]
report_timing_summary -file [file join $reports_dir timing_summary_synth.rpt]

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
}
open_run impl_1
report_utilization -file [file join $reports_dir utilization_impl.rpt]
report_timing_summary -file [file join $reports_dir timing_summary_impl.rpt]
report_drc -file [file join $reports_dir drc_impl.rpt]

set drc_violations [get_drc_violations -quiet]
if {[llength $drc_violations] != 0} {
    error "Post-route DRC failed with [llength $drc_violations] violation(s); see [file join $reports_dir drc_impl.rpt]"
}

set worst_setup_path [get_timing_paths -delay_type max -max_paths 1]
set worst_hold_path [get_timing_paths -delay_type min -max_paths 1]
if {[llength $worst_setup_path] == 0 || [get_property SLACK $worst_setup_path] < 0.0} {
    error "Post-route setup timing failed"
}
if {[llength $worst_hold_path] == 0 || [get_property SLACK $worst_hold_path] < 0.0} {
    error "Post-route hold timing failed"
}

set bit_file [file join [get_property DIRECTORY [get_runs impl_1]] design_1_wrapper.bit]
if {![file exists $bit_file]} {
    error "Expected bitstream was not generated: $bit_file"
}
file copy -force $bit_file [file join $artifacts_dir gem2_j10b.bit]
write_hw_platform -fixed -include_bit -force -file [file join $artifacts_dir gem2_j10b.xsa]
puts "BUILD_RESULT: SUCCESS"
puts "BITSTREAM: [file join $artifacts_dir gem2_j10b.bit]"
puts "XSA: [file join $artifacts_dir gem2_j10b.xsa]"
close_project
