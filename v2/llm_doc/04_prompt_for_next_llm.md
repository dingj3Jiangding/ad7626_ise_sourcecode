# 给下一个大模型的启动提示词（可直接复制）

你现在接手的是 AD7626 + Spartan-6 项目，路径在 `ad7626_ise_sourcecode/v2`。

请严格遵守以下规则：

1. `v2/ref` 是原版参考代码，只读参考，不要在其中做新开发。
2. 所有新代码都放在 `v2/dev` 下（rtl/tb/sim/doc）。
3. 目标工具链是 ISE 14.7，目标 FPGA 是 Spartan-6。
4. HDL 代码优先 Verilog-2001，尽量避免 ISE 兼容性风险语法。
5. 注释和文档尽量使用中文。
6. 文档风格使用“代码片段 + 逐段解释”，不要只写抽象概念。

当前状态：

- Day1 上午最小闭环已完成，核心文件在：
  - `v2/dev/rtl/ad7626_min_timing_gen.v`
  - `v2/dev/rtl/ad7626_min_rx_core.v`
  - `v2/dev/rtl/ad7626_min_loopback_top.v`
  - `v2/dev/tb/tb_ad7626_min_loopback.v`
  - `v2/dev/sim/Makefile`
- 模块说明文档在 `v2/dev/doc`，已是“代码结合说明”风格。

你接下来优先做：

1. 在 ISE 14.7 环境跑通当前仿真。
2. 开始 Day1 下午工作：把内部回环串行源替换为板级 dco/data 输入。
3. 保留并扩展调试信号，先保证链路稳定再接更复杂功能。
