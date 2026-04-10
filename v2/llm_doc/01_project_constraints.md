# 项目约束与边界

## 1. 平台与工具链

- 目标 FPGA：Spartan-6。
- 工具链：ISE 14.7（仿真与综合/实现/烧录都按 ISE 流程）。
- 当前对话执行环境无 ISE，因此本地未做最终 ISim 实测。

## 2. 目录约束

- 新开发代码统一放在 `v2/dev`。
- 原版参考代码放在 `v2/ref`。
- 规则：`v2/ref` 只读参考，不在 `v2/ref` 里提交新实现。

## 3. 已创建的开发骨架

- RTL：
  - `v2/dev/rtl/ad7626_min_timing_gen.v`
  - `v2/dev/rtl/ad7626_min_rx_core.v`
  - `v2/dev/rtl/ad7626_min_loopback_top.v`
- Testbench：
  - `v2/dev/tb/tb_ad7626_min_loopback.v`
- 仿真入口：
  - `v2/dev/sim/Makefile`
  - `v2/dev/sim/isim.prj`
  - `v2/dev/sim/isim_run.tcl`
- 文档：
  - `v2/dev/README.md`
  - `v2/dev/doc/*.md`

## 4. 当前开发阶段

- 已完成：Day1 上午最小数字闭环（时序发生 + 串行移位接收 + 数据一致性检查）。
- 待进行：Day1 下午，替换内部回环数据源为真实板级接口（dco/data）。

## 5. 关键技术约束

- 以 Verilog-2001 为主，优先兼容 ISE 14.7。
- 避免引入老工具链不稳定特性（如依赖 SystemVerilog 新语法）。
- 对仿真错误处理采用 ISE/ISim 友好方式。
