# 给下一个大模型的启动提示词（可直接复制）

你现在接手的是 AD7626 + Spartan-6 项目，路径在 `ad7626_ise_sourcecode/v2`。

请严格遵守以下规则：

1. `v2/ref` 是原版参考代码，只读参考，不要在其中做新开发。
2. 所有新代码都放在 `v2/dev` 下。
3. 目标工具链是 ISE 14.7，目标 FPGA 是 Spartan-6。
4. HDL 代码优先 Verilog-2001，尽量避免 ISE 兼容性风险语法。
5. 注释和文档尽量使用中文。
6. 文档风格使用“代码片段 + 逐段解释”，不要只写抽象概念。

当前状态：

- Day1 上午最小闭环已完成，核心文件在：
  - `v2/dev/rtl/Day1-1/ad7626_min_timing_gen.v`
  - `v2/dev/rtl/Day1-1/ad7626_min_rx_core.v`
  - `v2/dev/rtl/Day1-1/ad7626_min_loopback_top.v`
  - `v2/dev/tb/tb_ad7626_min_loopback.v`
- Day1-2 板级 echoed-clock 最小实现已完成，核心文件在：
  - `v2/dev/rtl/Day1-2/ad7626_day1_2_timing_gen.v`
  - `v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`
  - `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`
  - `v2/dev/constraints/ad7626_day1_2_board_top_template.ucf`
  - `v2/dev/tb/Day1-2/tb_ad7626_day1_2_board_top.v`
- 模块说明文档在 `v2/dev/human_doc`。
- 当前默认 bring-up 口径：
  - `tCYC = 240 ns`
  - `tCNVH = 20 ns`
  - `tMSB = 100 ns`
  - `tCLK = 4 ns`
- `tCYC = 200 ns` 当前被认为太紧，不应再作为默认值。

实现边界：

1. 当前接收已经是 `DCO` 驱动的 source-synchronous 方案。
2. 顶层假设外部已经提供 `sys_clk_250`。
3. `CNV` 当前按差分 LVDS 输出。
4. 如果实际板子上 `CNV` 是单端 2.5 V CMOS，需要改 top 和约束。

你接下来优先做：

1. 确认板上系统时钟来源，必要时补一个 `sys_clk_250` 的 DCM/PLL wrapper。
2. 按原理图填写 `v2/dev/constraints/ad7626_day1_2_board_top_template.ucf`。
3. 在 ISE 14.7 环境做综合/实现验证。
4. 如果板测暴露问题，再补更严格的 source-synchronous 约束，而不是退回普通系统时钟同步采样。

注意：

1. 不要再按旧思路去做“先把板级输入做两级同步”的占位方案。
2. 当前仓库里没有可直接运行的 `v2/dev/sim/Makefile`。
