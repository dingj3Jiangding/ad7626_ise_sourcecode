# ad7626_day1_2_timing_gen 结合代码说明

对应源码：`v2/dev/rtl/Day1-2/ad7626_day1_2_timing_gen.v`

## 1. 这个模块是干什么的

这个模块把一个 AD7626 sample 周期切成 4 段：

1. `CNV` 高电平窗口
2. 等待 `tMSB`
3. 16 个 `CLK` burst
4. burst 后保护窗口

核心参数：

```verilog
parameter integer CNV_PERIOD_CYCLES = 60,
parameter integer CNV_HIGH_CYCLES   = 5,
parameter integer MSB_WAIT_CYCLES   = 25,
parameter integer READ_PULSE_CYCLES = 16,
parameter integer POST_READ_GUARD_MIN_CYCLES = 18
```

在 `sys_clk_250` 前提下，它们分别对应：

1. `240 ns`
2. `20 ns`
3. `100 ns`
4. `64 ns`
5. `72 ns`

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
read_start  <= (phase_cnt == MSB_WAIT_CYCLES);
read_done   <= (phase_cnt == READ_END_CYCLES);
cnv         <= (phase_cnt < CNV_HIGH_CYCLES);
clk_gate    <= ((phase_cnt >= MSB_WAIT_CYCLES) &&
                (phase_cnt < READ_END_CYCLES));
```

理解方式：

1. `phase_cnt` 就是一整个 sample 周期里的相位计数器。
2. 前 `CNV_HIGH_CYCLES` 个时钟拉高 `CNV`。
3. 到 `MSB_WAIT_CYCLES` 后打开 `clk_gate`。
4. `clk_gate` 一共持续 `READ_PULSE_CYCLES` 个系统时钟周期。

## 4. 为什么这里要有参数告警

模块里有几组 `initial` 告警，主要是为了防止把参数配到明显不合理：

1. `MSB_WAIT_CYCLES <= CNV_HIGH_CYCLES`
2. `READ_PULSE_CYCLES <= 0`
3. burst 窗口超出整个 `CNV_PERIOD`
4. burst 后保护窗口小于推荐值

其中第 4 点最重要，因为它正对应你这次一直在讨论的 `tCYC` 是否太紧的问题。
