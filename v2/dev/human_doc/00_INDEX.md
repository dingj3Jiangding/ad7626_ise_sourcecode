# v2/dev RTL 文档索引

本文档目录对应 `v2/dev/rtl` 下的最小闭环模块。

## 阅读顺序建议

1. `01_ad7626_min_timing_gen.md`
2. `02_ad7626_min_rx_core.md`
3. `03_ad7626_min_loopback_top.md`
4. `04_day1_pm_hw_bringup_plan.md`
5. `05_datasheet_timing_fill_form.md`
6. `06_day1_2_checkpoint_design.md`
7. `07_ad7626_day1_2_timing_gen.md`
8. `08_ad7626_s6_serial_capture.md`
9. `09_ad7626_day1_2_board_top.md`
10. `10_day1_2_overlap_read_fix.md`
11. `11_day1_2_board_top_100m.md`
12. `12_day1_2_static_timing_report.md`

## 本次文档风格

每份文档都按下面结构组织，方便你“对着代码看逻辑”：

1. 先贴关键源码片段。
2. 对片段做逐段解释（输入/输出/状态变化）。
3. 给一个最小时序或数据流示例。
4. 总结在 ISE 14.7 / Spartan-6 下需要关注的点。

## 模块关系

- `ad7626_min_timing_gen`：生成帧起始与位采样节拍。
- `ad7626_min_rx_core`：按节拍接收串行位流并组帧输出。
- `ad7626_min_loopback_top`：把时序发生器和接收核连接起来，并内置测试串行源做 Day1 数字闭环。
- `ad7626_day1_2_timing_gen`：生成 AD7626 echoed-clock 读数周期的 `CNV` / `CLK` burst 窗口。
- `ad7626_s6_serial_capture`：在 Spartan-6 上用 `DCO` 接收 `D` 并跨域输出 16bit 样本。
- `ad7626_day1_2_board_top`：Day1-2 板级顶层，保留 fake/hw 双模式并导出上板调试信号。

## Day1 上午验证目标

- 连续产生有效采样脉冲 `sample_valid`。
- `sample_count` 递增不中断。
- 无 `align_error`。
- 无 `mismatch_error`。
