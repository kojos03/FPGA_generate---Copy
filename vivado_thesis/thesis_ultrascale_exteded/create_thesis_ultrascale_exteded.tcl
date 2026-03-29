# Vivado project recreation script for extended wildfire thesis design
# Target folder: vivado_thesis/thesis_ultrascale_exteded

set script_dir   [file normalize [file dirname [info script]]]
set repo_root    [file normalize [file join $script_dir .. ..]]
set project_name thesis_ultrascale_exteded
set part_name    xczu7ev-ffvc1156-2-e
set project_file [file join $script_dir "${project_name}.xpr"]

if {[file exists $project_file]} {
  open_project $project_file
} else {
  create_project $project_name $script_dir -part $part_name
}
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]
set_property default_lib work [current_project]

if {[llength [get_files -quiet -of_objects [get_filesets sources_1]]] > 0} {
  remove_files -fileset sources_1 [get_files -of_objects [get_filesets sources_1]]
}

if {[llength [get_files -quiet -of_objects [get_filesets sim_1]]] > 0} {
  remove_files -fileset sim_1 [get_files -of_objects [get_filesets sim_1]]
}

set design_sources [list \
  [file normalize [file join $repo_root VHDL config.vhd]] \
  [file normalize [file join $repo_root VHDL control.vhd]] \
  [file normalize [file join $repo_root VHDL multiplier.vhd]] \
  [file normalize [file join $repo_root VHDL sigmoid_lut.vhd]] \
  [file normalize [file join $repo_root VHDL sigmoid_IP.vhd]] \
  [file normalize [file join $repo_root VHDL neuron.vhd]] \
  [file normalize [file join $repo_root VHDL frame_stats.vhd]] \
  [file normalize [file join $repo_root VHDL fire_frame_aggregator.vhd]] \
  [file normalize [file join $repo_root VHDL temporal_tracker.vhd]] \
  [file normalize [file join $repo_root VHDL decision_layer.vhd]] \
  [file normalize [file join $repo_root VHDL nn_rgb.vhd]] \
  [file normalize [file join $repo_root VHDL nn_rgb_board_top.vhd]] \
]

add_files -fileset sources_1 $design_sources
set_property top nn_rgb_board_top [get_filesets sources_1]

set sim_sources [list \
  [file normalize [file join $repo_root VHDL tb_nn_rgb.vhd]] \
  [file normalize [file join $repo_root VHDL sim_nn_rgb.vhd]] \
]

add_files -fileset sim_1 $sim_sources
set_property top tb_nn_rgb [get_filesets sim_1]
set_property top_lib work [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
close_project

puts "Vivado project created at: $script_dir"
puts "Top (synthesis): nn_rgb_board_top"
puts "Part: $part_name"
