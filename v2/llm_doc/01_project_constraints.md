# 项目约束与边界

## 1. 平台与工具链

- 目标 FPGA：Spartan-6。
- 工具链：ISE 14.7。
- 当前对话执行环境没有 ISE，也没有 `iverilog` / `verilator` / `yosys`，所以本地没有完成综合级语法验证。

## 2. 目录约束

- 新开发代码统一放在 `ad7626_ise_sourcecode/v2/dev`。
- 原版参考代码放在 `ad7626_ise_sourcecode/v2/ref`。
- 规则：`v2/ref` 只读参考，不在其中做新实现。

## 3. 当前开发骨架

- RTL：
  - `v2/dev/rtl/Day1-1/ad7626_min_timing_gen.v`
  - `v2/dev/rtl/Day1-1/ad7626_min_rx_core.v`
  - `v2/dev/rtl/Day1-1/ad7626_min_loopback_top.v`
  - `v2/dev/rtl/Day1-2/ad7626_day1_2_timing_gen.v`
  - `v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`
  - `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`
- Testbench：
  - `v2/dev/tb/tb_ad7626_min_loopback.v`
  - `v2/dev/tb/Day1-2/tb_ad7626_day1_2_board_top.v`
- 约束模板：
  - `v2/dev/constraints/ad7626_day1_2_board_top_template.ucf`
- 文档：
  - `v2/dev/README.md`
  - `v2/dev/human_doc/*.md`

## 4. 当前开发阶段

- 已完成：
  - Day1 上午最小数字闭环。
  - Day1-2 板级 echoed-clock 最小实现。
- Day1-2 当前默认口径：
  - `tCYC = 100 ns`
  - `tCNVH = 20 ns`
  - `tMSB = 100 ns`
  - `tCLK = 4 ns`
  - `READ_START = 20 ns in cycle(N+1)`
- 当前未完成：
  - `sys_clk_250` 的板级来源封装。
  - 实际板卡 `LOC` 填写。
  - ISE 环境下综合/实现验证。
  - 更严格的 source-synchronous 约束细化。

## 5. 关键技术约束

- 以 Verilog-2001 为主，优先兼容 ISE 14.7。
- 避免依赖新式 SystemVerilog 语法。
- `v2/ref` 只用来学习层次和接口职责，不直接迁移为新开发主路径。
- AD7626 echoed-clock 模式必须按 `DCO` 做 source-synchronous 接收，不能把 `D` 当普通系统时钟同步输入处理。
- Day1-2 的读数模型已经改成：
  - `CNV(N)` 启动 conversion `N`
  - `cycle(N+1)` 的固定 burst 读窗读出 sample `N`
