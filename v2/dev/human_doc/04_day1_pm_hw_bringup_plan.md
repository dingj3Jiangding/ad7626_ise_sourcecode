# Day1 下午任务说明（硬件接入第一阶段）

对应阶段：把 Day1 上午的纯数字回环，过渡到“真实板级输入”的最小可用链路。

## 1. 本阶段目标

用最小改动实现以下闭环：

1. FPGA 仍生成采样节拍（`frame_start`、`bit_tick`）。
2. 串行数据来源从内部 fake ADC 切换为板级真实输入。
3. 接收链继续输出 `sample_valid`、`sample_data`、`sample_count`。
4. 保留并扩展调试观测信号，便于 ILA 快速定位问题。

一句话：先把“真板输入能跑起来”做通，再做更复杂优化。

## 2. Day1 下午完成定义（DoD）

满足以下条件即可认为 Day1 下午完成：

1. 能在板上观察到 `sample_valid` 周期出现。
2. `sample_count` 持续递增，无长时间停滞。
3. `align_error` 不持续触发（偶发可记录，但不能常态为 1）。
4. 能通过 ILA 同时观测：
   - `frame_start_dbg`
   - `bit_tick_dbg`
   - `serial_data_dbg`
   - `sample_valid`
   - `sample_count`
5. 代码中保留 fake 模式开关，便于回退验证。

## 3. 与 Day1 上午相比，具体改什么

当前文件：`v2/dev/rtl/ad7626_min_loopback_top.v`

现在是内部生成测试数据：

- `tx_word` / `tx_shift` 产生 fake 串行流。
- `serial_bit_s` 来自 `tx_shift[SAMPLE_WIDTH-1]`。

Day1 下午要做的是：

1. 增加“数据源选择”机制：
   - fake 源（保留）
   - 硬件源（新增）
2. 在硬件源模式下，把 `serial_in` 改为板级输入路径。
3. 保留现有 `rx_core` 与计数/错误框架，先减少变量。

## 4. 建议实现路线（先易后难）

## 4.1 Step A：先做可切换数据源（必做）

在 `ad7626_min_loopback_top.v` 增加参数或端口：

- 参数示例：`DATA_SRC_SEL`（0=fake，1=hw）
- 或端口示例：`input wire use_hw_data`

并做 MUX：

```verilog
assign serial_bit_s = (use_hw_data) ? serial_hw_s : tx_shift[SAMPLE_WIDTH-1];
```

目标：不改 testbench 也能继续跑 fake 模式，硬件联调时再切到 hw 模式。

## 4.2 Step B：硬件输入先做“最小同步版”（Day1 下午建议）

新增板级输入端口（先单端占位，后续可升级差分）：

- `adc_data_in`
- `adc_dco_in`（先用于观测，不一定立刻参与采样决策）

最小同步法（用于 bring-up）：

1. 在 `clk` 域对 `adc_data_in` 做两级同步，得到 `serial_hw_s`。
2. `rx_core` 仍按 `bit_tick_s` 移位接收。

说明：

- 这个方法实现最快，适合 Day1 下午先看链路“有无生命体征”。
- 该方法不是最终高速稳态方案，后续需升级到 dco 域采样。

## 4.3 Step C：增加硬件联调观测点（必做）

建议增加这些 debug 输出：

1. `adc_data_sync_dbg`（同步后的硬件数据）
2. `adc_dco_sync_dbg`（同步后的 dco）
3. `hw_mode_dbg`（当前是否硬件模式）
4. `bit_tick_count_dbg`（可选，统计位脉冲数量）

目的：让 ILA 一眼看出是“没进数据”还是“进了但组帧错”。

## 4.4 Step D：预留下一阶段接口（建议）

下一阶段（Day2）会做更稳妥的 dco 域采样，建议现在先预留文件名和模块边界：

- `v2/dev/rtl/ad7626_s6_serial_capture.v`（预留）

职责预期：

1. 在 dco 域移位采样 18bit。
2. 通过握手把完整字送到 `clk` 域。
3. 在 `clk` 域产生 `sample_valid_hw`。

## 5. 代码改动建议清单（文件级）

Day1 下午建议只改 1~2 个文件：

1. `v2/dev/rtl/ad7626_min_loopback_top.v`
   - 增加硬件输入端口/模式选择。
   - 增加同步寄存器和 debug 输出。
   - fake 路径保留。
2. `v2/dev/doc/03_ad7626_min_loopback_top.md`
   - 补“fake/hw 双模式”说明。

可选：

3. 新增 `v2/dev/doc/05_day1_pm_bringup_checklist.md`
   - 记录每次板上测试结果与参数。

## 6. 你需要补充的 Datasheet / 板卡信息清单

以下信息建议你先补齐，补齐后硬件接入会更稳：

## 6.0 已从 Datasheet 确认的信息（2026-04-10）

以下条目已确认，可直接用于 Day1 下午实现：

1. 位序：MSB first。
2. 无 dummy bit，frame 之间 D=0。
3. 每个 CNV frame 输出 16bit 数据。
4. CNV 到第一位出现延迟：`tMSB`。
5. CNV 周期：`tCYC`。
6. CNV 上升沿触发转换，且在 `tCNVH` 内需拉回低电平。
7. CNV 结束节点到最后一位（LSB）时间：`tCLKL`。
8. DCO 下降沿采样 D。

对 RTL 的直接影响：

1. `SAMPLE_WIDTH` 应按 16 先做 bring-up 配置（后续若模式变化再参数化扩展）。
2. 接收逻辑按 MSB-first 组织，无需 dummy bit 丢弃流程。
3. 采样边沿在 dco 下降沿，Day2 进入 dco 域采样时要严格按该边沿实现。

## 6.1 仍需补齐的必须项（没有就容易走弯路）

1. `tMSB` / `tCYC` / `tCNVH` / `tCLKL` 的具体数值（min/typ/max）。
2. DCO 下降沿采样对应的 setup/hold 具体数值（min/typ/max）。
3. 数据有效窗口在当前目标采样率下的裕量评估。
4. 板级引脚映射：
   - ADC 到 Spartan-6 的实际引脚名
   - 单端/差分连接方式
5. I/O 电平标准：
   - LVDS / LVCMOS 电平
   - 对应 ISE 约束中的 `IOSTANDARD`

## 6.2 建议项（影响后续稳定性）

1. 最大目标采样率与当前时钟规划。
2. 板上终端/阻抗网络（是否外部已终端）。
3. 复位后 ADC 初始化要求（上电等待、模式脚配置）。
4. 可用于验证的已知输入信号（直流、低频正弦、基准电压）。

## 7. 板上联调时的最小检查顺序

1. 先确认 `frame_start_dbg` 与 `bit_tick_dbg` 正常。
2. 再看 `serial_data_dbg` 是否有翻转活动。
3. 再看 `sample_valid` 是否按帧出现。
4. 最后看 `sample_count` 是否连续增长。
5. 若增长但数据异常，再检查位序/采样边沿。

## 8. 典型失败现象与快速定位

1. `sample_valid` 无脉冲：
   - 优先检查 `bit_tick` 是否产生、`frame_start` 是否被触发。
2. `sample_count` 不增长：
   - 检查 `rx_core` 是否收到连续位流。
3. `align_error` 常态为 1：
   - 帧与位节拍关系不对，或切换模式后时序断裂。
4. 数据跳变离散但无规律：
   - 大概率是异步采样导致，需升级到 dco 域采样方案。

## 9. 结论

Day1 下午不是追求“最终高速最优实现”，而是追求：

1. 真板输入接通。
2. 调试观测完整。
3. 代码可回退（fake/hw 双模式）。

做到这三点，Day2 再做 dco 域稳态优化会非常顺畅。
