# Create or refresh the Basys 3 digital clock project with Vivado 2018.1.
set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_name digital_clock
set project_dir [file join $root_dir vivado_project]
set project_file [file join $project_dir ${project_name}.xpr]

if {[file exists $project_file]} {
    open_project $project_file
} else {
    create_project $project_name $project_dir -part xc7a35tcpg236-1
}
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set design_file [file normalize [file join $root_dir rtl digital_clock.v]]
set xdc_file [file normalize [file join $root_dir constraints basys3_clock.xdc]]
set tb_file [file normalize [file join $root_dir sim tb_digital_clock.v]]
if {[llength [get_files -quiet $design_file]] == 0} {
    add_files -norecurse $design_file
}
if {[llength [get_files -quiet $xdc_file]] == 0} {
    add_files -fileset constrs_1 -norecurse $xdc_file
}
if {[llength [get_files -quiet $tb_file]] == 0} {
    add_files -fileset sim_1 -norecurse $tb_file
}

set_property top digital_clock [get_filesets sources_1]
set_property top tb_digital_clock [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Vivado project ready: $project_file"
close_project
