# 04 system_constr.xdc 详解

源文件：projects/ad762x_fmc/zed/system_constr.xdc

## 1. 这个文件的角色

它定义板级约束：

1. 引脚绑定
2. I/O 电平标准
3. 输入延时约束
4. 时钟关系与不确定度

## 2. 关键片段 1：差分引脚与电平

```tcl
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports ref_clk_p]
set_property -dict {PACKAGE_PIN C19 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports ref_clk_n]

set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports dco_p]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports dco_n]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports d_p]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports d_n]
```

解释：

- 采样相关信号全部是 LVDS_25。
- 输入差分线启用了片内终端 DIFF_TERM。

迁移提示：

- Spartan-6 是否支持对应终端和 bank 电压，需要按器件手册重核。

## 3. 关键片段 2：输出时钟与 CNV 引脚

```tcl
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVDS_25} [get_ports clk_p]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVDS_25} [get_ports clk_n]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVDS_25} [get_ports cnv_p]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVDS_25} [get_ports cnv_n]
```

解释：

- clk_p/n 与 cnv_p/n 是 FPGA 主动输出到 ADC 的差分线。
- 迁移时要先锁定新板原理图中的 ADC 连接器引脚，再写约束。

## 4. 关键片段 3：时钟约束

```tcl
create_clock -period 8.000 -name dco       [get_ports dco_p]
create_clock -period 8.000 -name out_clock [get_ports clk_p]
```

解释：

- dco 与 out_clock 都按 8ns（125MHz）建模。
- 这只是参考设计配置，不必直接照抄到新板。

## 5. 关键片段 4：输入延时和时钟不确定度

```tcl
set_input_delay -clock [get_clocks dco] -clock_fall -max  1.000 [get_ports d_p]
set_input_delay -clock [get_clocks dco] -clock_fall -min -1.000 [get_ports d_p]

set_clock_uncertainty -setup -from [get_clocks out_clock] -to [get_clocks dco] 5.000
```

解释：

- 这是建立数据输入窗口的关键约束。
- 只对 d_p 示范，实际迁移要覆盖 d_p/d_n 与相位关系。

## 6. Spartan-6 迁移建议

1. 工具链从 XDC 迁移到 UCF/约束语法时，逐条做语义映射。
2. 先保证时钟定义正确，再做 input delay 收敛。
3. 约束初版不追求极限，先能稳定采样，再做优化。

## 7. 你应该从这个文件得到什么

1. 新板 pin planning 需要的信号全集。
2. I/O 标准与终端策略。
3. 时序约束最小骨架。
