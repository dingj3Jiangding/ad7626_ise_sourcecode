# 当前会话进度与下一步

## 已完成事项

1. 确立目录策略：
   - `v2/ref` 作为参考代码区。
   - `v2/dev` 作为新开发区。
2. 完成 Day1 上午最小闭环实现：
   - 时序发生器 `ad7626_min_timing_gen`。
   - 串行接收核 `ad7626_min_rx_core`。
   - 回环顶层 `ad7626_min_loopback_top`。
3. 补齐 testbench 与仿真入口：
   - `tb_ad7626_min_loopback`。
   - ISim 所需 `isim.prj` / `isim_run.tcl`。
4. 补齐模块说明文档：
   - `v2/dev/doc/01~03` 已更新为“代码结合说明”风格。
5. Day1 上午仿真验证通过（用户已在本地环境确认）。
6. 已确认关键 datasheet 条件：
   - MSB first。
   - 无 dummy bit，frame 间 D=0。
   - 每 frame 输出 16bit。
   - CNV 上升沿触发转换，DCO 下降沿采样。
   - 已定位关键时序符号：`tMSB`、`tCYC`、`tCNVH`、`tCLKL`。

## 尚未完成事项

1. Day1 下午：接入真实板级 dco/data 输入，替换内部回环串行源。
2. 新增板级最小顶层与约束模板（Spartan-6 引脚/时钟约束）。
3. 补齐时序参数具体值（`tMSB`/`tCYC`/`tCNVH`/`tCLKL` min/typ/max 与 setup/hold 数值）。

## 推荐下一步执行顺序

1. 先在有 ISE 的机器上跑通当前仿真。
2. 新建板级接口模块（建议命名 `ad7626_s6_io_if`）。
3. 先保持 `ad7626_min_rx_core` 不改，只替换 `serial_in` 来源。
4. 保留 `sample_valid/sample_count/align_error/mismatch_error` 作为第一版硬件调试观测口。

## 验收标准（当前阶段）

- 仿真输出出现 PASS 文本。
- 无 `align_error`。
- 无 `mismatch_error`。
- `sample_count` 连续递增。
