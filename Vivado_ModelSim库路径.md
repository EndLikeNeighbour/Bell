# Vivado 2018.1 project settings and installed simulator-library paths

## Vivado setting (`Compiled Library Paths`)

This project is configured to use ModelSim:

- Target simulator: `ModelSim`
- Compiled library directory property in the XPR: `$PPRDIR/../../vivado_project/digital_clock.cache/compile_simlib/modelsim`
- Expanded path, relative to the XPR directory: `E:\Project\ModelsimProject\数字钟\vivado_project\vivado_project\digital_clock.cache\compile_simlib\modelsim`

**Important:** This is a configured destination, not a currently populated compiled-library directory. The directory does not exist in this project yet, and the clock RTL/testbench do not instantiate Xilinx simulation primitives, so a third-party compiled library is not needed for the current RTL behavioral test.

If you later need Vivado's Xilinx simulation libraries for ModelSim, compile them in Vivado 2018.1 with the project open:

```tcl
compile_simlib -simulator modelsim \
  -simulator_exec_path {F:/ProgramFiles/Modelsim/win64pe} \
  -family artix7 -library unisim -library simprim \
  -directory {E:/Project/ModelsimProject/数字钟/vivado_project/digital_clock.cache/compile_simlib/modelsim}
```

After compilation, point **Tools → Settings → 3rd Party Simulators → ModelSim → Compiled Library Paths** (the exact label/location can vary slightly by Vivado build) to the generated ModelSim library directory and use the `modelsim.ini` created there. Do not point this field to the raw HDL source folders or to ModelSim's `work` library.

## Existing ModelSim libraries on this PC

The existing Xilinx ModelSim library installation found on this PC is:

- Xilinx library root: `F:\ProgramFiles\Xilinx\Xilib`
- `unisim`: `F:\ProgramFiles\Xilinx\Xilib\unisim`
- `unisims_ver`: `F:\ProgramFiles\Xilinx\Xilib\unisims_ver`

These folders contain ModelSim library databases (`_lib.qdb`, `_lib1_0.qdb`), so they are compiled libraries. Other Xilinx mappings also appear in `F:\ProgramFiles\Xilinx\Xilib\modelsim.ini`, but not every mapped directory was confirmed present. The installed ModelSim executable directory is `F:\ProgramFiles\Modelsim\win64pe`.

## Project-local ModelSim simulation

The standalone RTL self-test uses a local ModelSim configuration and the project's `sim_work` library. It does not require the Vivado precompiled Xilinx libraries. Use `run_modelsim.cmd` from the project root to avoid ModelSim 10.6c's Unicode path problem.
