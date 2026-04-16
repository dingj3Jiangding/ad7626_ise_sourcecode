# ad7626_day1_2_board_top 结合代码说明

对应源码：`v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`

注意：

1. 这份文档讲的是 `250 MHz` 内核顶层。
2. 如果你的板上原生时钟是 `100 MHz`，当前推荐外层顶层已经变成 `ad7626_day1_2_board_top_100m.v`。

## 1. 这个 top 解决什么问题

这是当前 Day1-2 的板级顶层。

它做三件核心事情：

1. 产生 `CNV±` 和 `CLK±`
2. 接收 `DCO±` 和 `D±`
3. 维护 `start/finish` 两段样本流水，并输出系统侧调试与样本接口

## 2. 顶层端口的核心分组

### 2.1 时钟与 ADC 接口

```verilog
input  wire sys_clk_250,
input  wire dco_p,
input  wire dco_n,
input  wire d_p,
input  wire d_n,
output wire clk_p,
output wire clk_n,
output wire cnv_p,
output wire cnv_n
```

说明：

1. `sys_clk_250` 是整个 Day1-2 设计的本地基准时钟。
2. `clk_p/n` 和 `cnv_p/n` 发给 ADC。
3. `dco_p/n` 和 `d_p/n` 从 ADC 回来。

### 2.2 系统侧观测口

```verilog
output wire sample_valid,
output wire [SAMPLE_WIDTH-1:0] sample_data,
output wire [COUNTER_WIDTH-1:0] sample_count,
output wire align_error,
output wire mismatch_error
```

说明：

1. `sample_*` 是系统侧真正关心的样本输出。
2. `align_error` 用来标记帧与接收结果没对上。
3. `mismatch_error` 只用于 fake 模式自检。

## 3. 为什么这里用 `ODDR2`

关键片段：

```verilog
ODDR2 i_clk_oddr2 (
  .C0(sys_clk_250),
  .C1(~sys_clk_250),
  .D0(clk_gate_s),
  .D1(1'b0)
);
```

它的作用是：

1. 当 `clk_gate_s = 1` 时，输出 `1010...` 的 250 MHz burst。
2. 当 `clk_gate_s = 0` 时，输出保持低。

这就刚好满足 AD7626 对 `CLK` 的要求：

1. 只在 burst 期间有时钟
2. 其余时间 idle low

`CNV` 那一路同理，只是 `D0/D1` 都接同一个 `cnv_s`，用来把单沿控制信号稳定送到差分输出对。

## 4. fake / hw 双模式有什么用

关键片段：

```verilog
assign hw_mode_s = (DATA_SRC_SEL != 0);
```

含义：

1. `DATA_SRC_SEL = 0` 时，使用内部 fake 样本路径。
2. `DATA_SRC_SEL != 0` 时，使用真实 ADC 返回的数据。

保留 fake 模式的好处：

1. 可以先验证系统侧计数与调试接口没有坏。
2. 板级出问题时，有一个快速回退通道。

这里当前实现里最重要的点是 `start/finish` 两段流水：

1. `start_word`：当前 `frame_start` 启动、并将在本周期 `read_start` 开始发送 head 的 sample。
2. `finish_word`：上一周期已经开始发送、并将在本周期 `read_done` 完成 tail 的 sample。

它比旧的 pending queue 更直接，因为 split-burst 的时间关系现在就是固定的“本周期 start、下一周期 finish”。

## 5. 当前 top 里最重要的参数告警

模块里会主动提示几类容易配错的情况：

1. `SAMPLE_WIDTH != 16`
2. `READ_PULSE_CYCLES != SAMPLE_WIDTH`
3. `CNV_HIGH_CYCLES` 不在 `10 ns ~ 40 ns` 对应的 250 MHz 周期范围内
4. `READ_START_CYCLES < MSB_WAIT_CYCLES`

这些告警不是最终约束，但对 first bring-up 很有帮助。

## 6. 上板时最该看哪些 debug

这个 top 额外导出了：

1. `frame_start_dbg`
2. `read_start_dbg`
3. `clk_gate_dbg`
4. `read_done_dbg`
5. `hw_mode_dbg`
6. `serial_data_dbg`
7. `adc_dco_dbg`
8. `cnv_dbg`
9. `phase_dbg`

其中最关键的是：

1. `read_start_dbg`
2. `clk_gate_dbg`
3. `adc_dco_dbg`

因为它们能直接告诉你：

1. burst 应该什么时候开始
2. burst 实际开了多长
3. ADC 有没有按预期回时钟

再补一个你现在看代码时最应该记住的时间线：

```text
frame N:
  phase 0      -> CNV(N)，同时把上一份 start_word 推到 finish_word
  phase 0..5   -> finish finish_word 的 tail
  phase 15..24 -> start start_word 的 head

frame N+1:
  phase 0..5   -> finish 本帧 start_word 的 tail
  phase 6      -> read_done
  phase 15..24 -> start 下一份样本的 head
```

所以 `sample_valid` 对应的是 `finish_word`，不是“本拍刚发 CNV 的样本”。
