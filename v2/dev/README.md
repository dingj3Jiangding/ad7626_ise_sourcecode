# v2/dev Day1 最小数字闭环

本目录用于放置新开发代码。
`v2/ref` 仅作为参考，不在其中做功能开发改动。

## Day1 上午目标

实现并验证最小闭环：

1. 时序发生（frame_start + bit_tick）。
2. 串行移位接收并组帧。
3. 输出 sample_valid / sample_data / sample_count。
4. 帧对齐错误检测与数据一致性检测。

## 文件说明

- `rtl/Day1-1/ad7626_min_timing_gen.v`
  生成帧起始与位采样节拍。
- `rtl/Day1-1/ad7626_min_rx_core.v`
  执行串行移位接收、样本有效脉冲与样本计数。
- `rtl/Day1-1/ad7626_min_loopback_top.v`
  内置递增测试模式串行源，回环到接收核，便于纯数字快速验证。
- `rtl/Day1-2/ad7626_day1_2_timing_gen.v`
  生成 AD7626 echoed-clock 模式所需的 `CNV`、读时钟 burst 与调试节拍。
- `rtl/Day1-2/ad7626_s6_serial_capture.v`
  在 Spartan-6 上用 `DCO` 接收 `D`，并把 16bit 样本跨回系统时钟域。
- `rtl/Day1-2/ad7626_day1_2_board_top.v`
  Day1-2 板级顶层，直接连接 AD7626 差分接口并保留 fake/hw 双模式。
- `constraints/ad7626_day1_2_board_top_template.ucf`
  板级约束模板，等待补实际引脚 `LOC`。
- `tb/tb_ad7626_min_loopback.v`
  自检 testbench，出现对齐或数据错误会直接失败。
- `tb/Day1-2/tb_ad7626_day1_2_board_top.v`
  Day1-2 硬件模式 testbench，内含 generic primitive stub 和简化 ADC 行为模型。

## 运行方法

当前仓库里已经有 Day1-1 的 testbench：

```bash
cd ad7626_ise_sourcecode/v2/dev/tb
```

说明：

1. 当前目录里只有 testbench 源文件，还没有补一键仿真脚本。
2. 如果你要在有 ISE 的机器上跑仿真，需要再按你的工程环境补 `fuse` / `isim` 启动脚本。
3. Day1-2 的前期验证入口是 `tb/Day1-2/tb_ad7626_day1_2_board_top.v`。

期望输出包含：

```text
[TB][PASS] Reached 128 samples without align/data errors.
```

## 下一步（Day1 下午之后）

1. 根据你的板子补 `sys_clk_250` 的产生方式。
2. 按原理图填写 `constraints/ad7626_day1_2_board_top_template.ucf` 的 `LOC`。
3. 上板验证 `CNV`、`CLK`、`DCO`、`D` 与 `sample_valid`。
4. 在硬件稳定后，再补更严格的时序约束和后续寄存器/采集链路。
