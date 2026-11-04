# Basys 3 简易电子时钟工程

## 工具与器件

- 开发板：Basys 3，XC7A35T-1CPG236C
- Vivado：2018.1
- ModelSim：DE-64 10.6c
- 板载时钟：100 MHz（10 ns）

## 功能操作

- `BTNC`：高有效同步复位，清零为 `00:00:00`。
- `SW0=0`：运行计时；`SW0=1`：暂停计时并进入设置。
- 设置模式下 `SW1=0` 选小时、`SW1=1` 选分钟；`BTNU` 加一，`BTND` 减一，字段循环回绕。秒在设置模式暂停。
- 运行模式下 `BTNL` 选择 `HH:MM`，`BTNR` 选择 `MM:SS`。默认页面为 `HH:MM`。
- `SW2=0` 使用手动页面选择；`SW2=1` 开启自动轮播，`HH:MM` 显示 5 秒、`MM:SS` 显示 3 秒，完整轮播周期 8 秒。关闭 `SW2` 后恢复轮播前的手动页面。轮播只在运行模式下计时，进入设置模式会暂停。
- `HH:MM` 页面中仅 AN2 的小数点作为冒号提示，随秒每秒交替亮灭；AN1 及其它小数点熄灭。
- `MM:SS` 页面中 AN2 小数点常亮作为分隔提示，AN0（秒个位）小数点常亮作为秒位标记；AN1 和 AN3 小数点熄灭。
- 四位共阳数码管动态扫描，段选和位选均低有效；`LD0` 表示设置模式，`LD1` 表示当前显示 `MM:SS`。
- `SW3=0` 为原电子时钟模式；`SW3=1` 进入计时器模式，后台时钟继续按 `SW0` 状态计时。计时器模式下 `SW4=0` 选择秒表，`SW4=1` 选择倒计时。
- 秒表显示 `SS.hh`（秒.百分之一秒），`BTNL` 启动/暂停，`BTNR` 清零并暂停；从 `59.99` 下一拍回到 `00.00`。
- 倒计时显示 `MM:SS`，暂停时 `SW1=0` 选择分钟、`SW1=1` 选择秒，`BTNU` 加一、`BTND` 减一，分钟/秒字段均在 `00`～`59` 间循环。`BTNL` 启动/暂停，暂停后再次启动从剩余值继续；`BTNR` 装载当前设定值并暂停。
- 倒计时设为 `00:00` 后启动会直接进入结束状态；正常倒数到 `00:00.00` 后停止，`LD7` 与 `LD8` 交替快速闪烁。按 `BTNR` 清除报警并重新装载设定值。
- 计时范围为 24 小时，`23:59:59` 后回到 `00:00:00`。

拨码开关经过两级同步，自动轮播使用 `SW2`（Basys 3 引脚 W16）。

## 文件结构

- `rtl/digital_clock.v`：综合用顶层 RTL。
- `sim/tb_digital_clock.v`：自检测试台，验证复位、时分调整回绕、暂停、数码管段码和 DP 指示、手动及自动页面选择、5 秒/3 秒轮播、轮播暂停/恢复、秒表启停/复位/59.99 回绕、倒计时设置/暂停续跑/归零报警，以及分钟/小时/24 小时进位。仿真加速参数只在 testbench 实例中使用。
- `constraints/basys3_clock.xdc`：时钟和 Basys 3 引脚约束。引脚依据项目目录所用的已交叉核对 Basys 3 引脚表。
- `scripts/create_vivado_project.tcl`：创建 Vivado 项目的 Tcl。
- `sim/run_modelsim.do`：ModelSim 编译、自检运行和结果代码检查脚本；不调用全局 `vmap`。
- `modelsim.ini`：项目本地 ModelSim 配置，配合 `-modelsimini` 使用，不写安装目录的全局配置。
- `run_modelsim.cmd`：临时分配空闲 ASCII 盘符，规避 ModelSim 10.6c 的中文路径编码问题；退出时移除映射。
- `vivado_project/digital_clock.xpr`：运行 Vivado 创建脚本后生成的工程。
- `simulation_logs/modelsim.log`：ModelSim 仿真输出。

## 创建 Vivado 工程

在工程根目录执行：

```bash
vivado -mode batch -source scripts/create_vivado_project.tcl
```

生成 `vivado_project/digital_clock.xpr`。也可在 Vivado GUI 中直接打开此 `.xpr`。

## 运行 ModelSim 自检

在工程根目录执行：

```bash
run_modelsim.cmd
```

成功时控制台末尾应输出 `ALL TESTS PASSED` 与 `MODELSIM RESULT: PASS`，并返回成功状态；详细记录写入 `simulation_logs/modelsim.log`。

测试台将秒计数器参数缩小以便快速覆盖完整 24 小时回绕；实际工程仍使用 100 MHz 输入和真实 1 秒计时。
