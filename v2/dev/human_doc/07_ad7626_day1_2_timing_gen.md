# ad7626_day1_2_timing_gen 结合代码说明

对应源码：`v2/dev/rtl/Day1-2/ad7626_day1_2_timing_gen.v`

## 1. 这个模块是干什么的

这个模块现在实现的是“跨两个 cycle 的分段 burst”。

它的节拍不是单段 `clk_gate`，而是两段：

1. 当前周期起点一小段，用来完成上一个 in-flight sample 的 tail。
2. 当前周期后半段一大段，用来开始下一个 sample 的 head。
3. `CNV` 仍然在每个周期起点发起。

核心参数：

```verilog
parameter integer CNV_PERIOD_CYCLES = 25,
parameter integer CNV_HIGH_CYCLES   = 5,
parameter integer MSB_WAIT_CYCLES   = 15,
parameter integer READ_START_CYCLES = 15,
parameter integer READ_PULSE_CYCLES = 17,
parameter integer TCLKL_CYCLES      = 10
```

在 `sys_clk_250` 前提下，它们分别对应：

1. `100 ns`
2. `20 ns`
3. `60 ns`
4. `60 ns`
5. `68 ns`
6. `40 ns`

在当前 split-burst 模型里，还会额外推导出两个量：

```text
READ_HEAD_CYCLES = CNV_PERIOD_CYCLES - READ_START_CYCLES = 10
READ_TAIL_CYCLES = READ_PULSE_CYCLES - READ_HEAD_CYCLES  = 7
```

也就是：

1. 每个周期末尾先发 `10` 个时钟。
2. 下一周期开头再补 `7` 个时钟。

这里最容易误解的是 `MSB_WAIT_CYCLES` 和 `READ_START_CYCLES`：

1. 当前实现里 `read_start` 由 `READ_START_CYCLES` 直接决定。
2. `MSB_WAIT_CYCLES` 仍然保留为“样本 readiness 假设”。
3. 当前这版代码要求两者相等，都是 `15`。
4. readiness 检查现在是：

```text
READ_START_CYCLES >= MSB_WAIT_CYCLES
```

也就是：

```text
15 cycles = 60 ns >= 60 ns
```

所以当前代码假设当前 sample 在同周期 burst head 开始前已经准备好了。

## 2. 输出信号怎么理解

```verilog
output reg cnv,
output reg clk_gate,
output reg frame_start,
output reg read_start,
output reg read_done
```

含义：

1. `cnv`：送到 ADC 的转换启动脉冲。
2. `clk_gate`：允许 `CLK` burst 输出的窗口。
3. `frame_start`：一个 sample 周期的起点。
4. `read_start`：开始进入 burst 读数窗口。
5. `read_done`：burst 完成后的标志。

## 3. 关键逻辑

```verilog
frame_start <= (phase_cnt == 0);
read_start  <= (phase_cnt == READ_START_CYCLES);
read_done   <= (phase_cnt == READ_TAIL_CYCLES);
cnv         <= (phase_cnt < CNV_HIGH_CYCLES);
clk_gate    <= ((phase_cnt >= READ_START_CYCLES) ||
                (phase_cnt < READ_TAIL_CYCLES));
```

理解方式：

1. `phase_cnt` 就是一整个 sample 周期里的相位计数器。
2. 前 `CNV_HIGH_CYCLES` 个时钟拉高 `CNV`。
3. 到 `READ_START_CYCLES` 后，打开当前周期末尾那一段 `clk_gate`。
4. 到下一周期 `READ_TAIL_CYCLES` 之前，保持下一周期开头那一段 `clk_gate`。
5. 两段拼起来，一共是 `READ_PULSE_CYCLES = 17` 个系统时钟周期。

可以用下面这个时间线去理解：

```text
cycle N:
  phase 0      -> 发 CNV(N)
  phase 0..5   -> 完成上一个 in-flight sample 的 tail
  phase 15..24 -> 发当前 in-flight sample 的 head

cycle N+1:
  phase 0..5   -> 完成当前 in-flight sample 的 tail
  phase 6      -> read_done
  phase 15..24 -> 开始下一个 sample 的 head
```

所以 `timing_gen` 现在本质上是在同一条相位轴上同时安排三件事：

1. 当前拍的转换启动
2. 上一个 sample 的 tail
3. 当前 sample 的 head

## 4. 为什么这里要有参数告警

模块里有几组 `initial` 告警，主要是为了防止把参数配到明显不合理：

1. `MSB_WAIT_CYCLES <= CNV_HIGH_CYCLES`
2. `READ_PULSE_CYCLES <= 0`
3. `READ_START_CYCLES < CNV_HIGH_CYCLES`
4. `READ_HEAD_CYCLES > TCLKL_CYCLES`
5. `READ_START_CYCLES < MSB_WAIT_CYCLES`
6. `READ_START_CYCLES != MSB_WAIT_CYCLES`
7. `READ_TAIL_CYCLES <= 0`

第 4 和第 5 点最关键：

1. 第 4 点检查当前周期末尾那一段 burst head 是否超出 `tCLKL` 预算。
2. 第 5 点检查当前 split-burst 起点之前，当前样本是否已经 ready。

按当前默认值：

```text
READ_HEAD_CYCLES = 25 - 15 = 10 cycles = 40 ns
READ_TAIL_CYCLES = 16 - 10 = 6 cycles = 24 ns
```

也就是：

1. 每个周期末尾先打 `40 ns` 的 head。
2. 下一周期开头再补 `24 ns` 的 tail。
