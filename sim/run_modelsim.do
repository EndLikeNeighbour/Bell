# Run via run_modelsim.cmd, which mounts this project on an ASCII drive letter.
file mkdir simulation_logs
if {![file exists sim_work]} { vlib sim_work }
transcript file simulation_logs/modelsim.log
transcript on
vlog -work work rtl/digital_clock.v sim/tb_digital_clock.v
vsim -onfinish stop work.tb_digital_clock
run -all
set error_count [examine -radix decimal sim:/tb_digital_clock/errors]
if {$error_count != 0} {
    puts "MODELSIM RESULT: FAIL ($error_count errors)"
    quit -code 1
} else {
    puts "MODELSIM RESULT: PASS"
    quit -code 0
}
