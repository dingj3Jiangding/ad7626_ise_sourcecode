# Day1-2 时序模型修正说明

用途：单独记录这一次 Day1-2 RTL 的关键修正，说明为什么原来的实现不对、现在改成了什么、以及当前默认参数是怎样落下来的。

对应改动文件：

1. `v2/dev/rtl/Day1-2/ad7626_day1_2_timing_gen.v`
2. `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`
3. `v2/dev/tb/Day1-2/tb_ad7626_day1_2_board_top.v`
4. `v2/dev/rtl/Day1-2/ad7626_day1_2_clkgen_100m_to_250m.v`
5. `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top_100m.v`

## 1. 这次改动的核心问题

原来的错误理解是：

1. `CNV(N)` 发出后，要在同一个 `tCYC` 里先等待 `tMSB`。
2. 然后再把 16 个 `CLK` 全部发完。
3. 因此会把 `tMSB + 16 x tCLK`` 强行塞进同一个 sample 周期。

这个理解不符合 AD7626 满速 echoed-clock 模式的重叠时序。

更合理的关系应该是：

1. 一个 16bit burst 被拆成两段。
2. 当前周期末尾先发 head。
3. 下一周期开头再补 tail。
4. sample read 可以和相邻周期的 acquisition / conversion 时间重叠。

一句话总结：

这次修正不是“微调参数”，而是把 Day1-2 的时间模型改对了。

## 2. 新的时序口径

当前采用的时间线如下：

```text
cycle N:
  phase 0      -> CNV(N)
  phase 0..5   -> 完成上一份 sample 的 tail
  phase 15..24 -> 开始当前 in-flight sample 的 head

cycle N+1:
  phase 0      -> CNV(N+1)
  phase 0..5   -> 完成当前 in-flight sample 的 tail
  phase 15..24 -> 开始下一份 sample 的 head
```

在 `sys_clk_250` 下：

1. 一个系统周期是 `4 ns`。
2. `READ_START_CYCLES = 15`，所以当前周期后半段在 `60 ns` 处打开。
3. `READ_PULSE_CYCLES = 16`，所以 burst 长度是 `64 ns`。
4. 当前周期 head 长度是 `10` cycles，即 `40 ns`。
5. 下一周期 tail 长度是 `6` cycles，即 `24 ns`。

## 3. 为什么当前参数是合理的

当前 Day1-2 默认参数：

| 参数 | 周期数 | 时间 |
|---|---:|---:|
| `CNV_PERIOD_CYCLES` | 25 | 100 ns |
| `CNV_HIGH_CYCLES` | 5 | 20 ns |
| `MSB_WAIT_CYCLES` | 15 | 60 ns |
| `READ_START_CYCLES` | 15 | 60 ns |
| `READ_PULSE_CYCLES` | 16 | 64 ns |
| `TCLKL_CYCLES` | 10 | 40 ns |

有两个关键检查。

第一条：当前周期末尾 burst head 是否落在 `tCLKL` 预算内。

```text
READ_HEAD_CYCLES = 25 - 15 = 10 cycles = 40 ns
```

所以它正好等于当前 `TCLKL_CYCLES = 10`。

第二条：当前 split-burst 起点之前，当前样本是否已经 ready。

```text
READ_START_CYCLES
= 15 cycles
= 60 ns
```

所以当前实现假设：

```text
60 ns >= MSB_WAIT_CYCLES x 4 ns = 60 ns
```

这说明当前代码现在把 `MSB_WAIT_CYCLES` 解释成“同周期 head 启动前的最小等待量”。

## 4. `timing_gen` 改了什么

关键修正前后的区别是：

```verilog
read_start <= (phase_cnt == READ_START_CYCLES);
read_done  <= (phase_cnt == READ_TAIL_CYCLES);
clk_gate   <= ((phase_cnt >= READ_START_CYCLES) || (phase_cnt < READ_TAIL_CYCLES));
```

含义变化：

1. `clk_gate` 不再是一段连续窗口，而是跨周期的两段窗口。
2. 当前周期末尾那段 head 由 `READ_START_CYCLES` 决定。
3. 下一周期开头那段 tail 由 `READ_TAIL_CYCLES` 决定。

当前 `timing_gen` 还加了几类检查：

1. `READ_START_CYCLES < CNV_HIGH_CYCLES`
2. `READ_HEAD_CYCLES > TCLKL_CYCLES`
3. `READ_START_CYCLES < MSB_WAIT_CYCLES`
4. `READ_TAIL_CYCLES <= 0`
5. `READ_START_CYCLES != MSB_WAIT_CYCLES`

这些检查的目的，是把“读窗太早”“读窗太长”“当前样本还没 ready 就开始读”“读窗跑出本周期”这几类典型配置错误提前暴露出来。

## 5. 对照 `timing_gen` 代码的 2-cycle 时序图

先把真正决定时序的代码摘出来：

```verilog
frame_start <= (phase_cnt == 0);
read_start  <= (phase_cnt == READ_START_CYCLES);
read_done   <= (phase_cnt == READ_TAIL_CYCLES);
cnv         <= (phase_cnt < CNV_HIGH_CYCLES);
clk_gate    <= ((phase_cnt >= READ_START_CYCLES) ||
                (phase_cnt < READ_TAIL_CYCLES));
```

当前默认参数代入后是：

```text
CNV_PERIOD_CYCLES = 25
CNV_HIGH_CYCLES   = 5
READ_START_CYCLES = 15
READ_HEAD_CYCLES  = 10
READ_TAIL_CYCLES  = 6
```

所以一个周期里，`phase_cnt` 的关键点是：

1. `phase_cnt = 0`：`frame_start = 1`
2. `phase_cnt = 0..4`：`cnv = 1`
3. `phase_cnt = 0..5`：`clk_gate = 1`，完成 tail
4. `phase_cnt = 6`：`read_done = 1`
5. `phase_cnt = 15`：`read_start = 1`
6. `phase_cnt = 15..24`：`clk_gate = 1`，开始 head

### 5.1 先看 cycle N 本身

```text
cycle N, phase_cnt = 0..24

phase_cnt    :  0    1    2    3    4    5    6   ...  14   15   16  ...  24
frame_start  :  1    0    0    0    0    0    0   ...   0    0    0  ...   0
cnv          :  1    1    1    1    1    0    0   ...   0    0    0  ...   0
read_start   :  0    0    0    0    0    0    0   ...   0    1    0  ...   0
clk_gate     :  1    1    1    1    1    1    0   ...   0    1    1  ...   1
read_done    :  0    0    0    0    0    0    1   ...   0    0    0  ...   0
```

这张表直接对应代码：

1. `frame_start <= (phase_cnt == 0)`，所以只有 phase 0 是 1。
2. `cnv <= (phase_cnt < 5)`，所以 phase 0 到 4 为高。
3. `read_start <= (phase_cnt == 15)`，所以只有 phase 15 打一个脉冲。
4. `clk_gate <= (phase_cnt >= 15 || phase_cnt < 6)`，所以 phase 15..24 和 0..5 为高，总共 16 个系统周期。
5. `read_done <= (phase_cnt == 6)`，所以 phase 6 打一个脉冲。

### 5.2 再把 cycle N 和 cycle N+1 连起来看

真正重要的是，你现在关心的不是“单拍里有什么信号”，而是“上一拍 sample 为什么会在下一拍读出”。

把两个周期拼起来就是：

```text
time ---->

cycle         : |<--------- cycle N --------->|<-------- cycle N+1 -------->|
phase_cnt     : |0..5|6..14|15........24|0..5|6..14|15........24|

frame_start   : | 1        |              |     | 1        |              |
cnv           : | 1   high |      low     | low | 1   high |      low     |
clk_gate      : | high |low |    high     |high | low |    high         |
read_start    : |      |    |  ^          |     |     |  ^              |
read_done     : |  ^   |    |             |  ^  |     |                 |

meaning       : |tail prev |   idle  |head current|tail current|idle|head next|
```

这里要非常明确：

1. `cycle N` 开头那 6 个 clock 是上一份 sample 的 tail。
2. `cycle N` 末尾那 10 个 clock 是当前 in-flight sample 的 head。
3. 下一周期开头再补这份 sample 的 tail。

### 5.3 用 sample 编号再写一遍

如果只看 sample 编号，最清楚的版本是：

```text
cycle N:
  phase 0      -> frame_start = 1, cnv = 1
  phase 0..5   -> clk_gate = 1，完成上一份 sample 的 tail
  phase 6      -> read_done = 1
  phase 15     -> read_start = 1
  phase 15..24 -> clk_gate = 1，开始当前 sample 的 head

cycle N+1:
  phase 0..5   -> clk_gate = 1，完成当前 sample 的 tail
  phase 6      -> read_done = 1
  phase 15..24 -> clk_gate = 1，开始下一份 sample 的 head
```

这就是为什么当前模型里：

```text
每个 16bit burst 被拆成：
当前周期 10 bit head + 下一周期 6 bit tail
```

### 5.4 这个 2-cycle 图和 `tMSB` 的关系

这两拍模型成立的前提，是当前样本到了本拍 `read_start` 之前已经 ready。

代码里对应的检查是：

```text
MSB_WAIT_CYCLES <= READ_START_CYCLES
```

当前默认值代入后：

```text
15 <= 15
```

换成时间就是：

```text
MSB_WAIT = 60 ns
从某次 frame_start 到下一次 split-burst head 起点一共 160 ns
```

所以：

1. 当前 split-burst 模型在时间上是自洽的。
2. `timing_gen` 可以用固定两段 `clk_gate`，不用运行时再算 stop 相位。

## 6. `board_top` 改了什么

这次另一个关键修正，是顶层不再用 pending queue 管样本。

现在的 `board_top` 里是 2 段流水：

1. `start_*`
   表示当前 `frame_start` 刚启动、并将在本周期 `read_start` 开始发送 head 的 sample。
2. `finish_*`
   表示上一周期已经开始发送、并将在本周期 `read_done` 完成 tail 的 sample。

可以这样理解：

1. 每次 `frame_start`，流水整体往前推一段：`start -> finish`，同时把当前新样本装进 `start_*`。
2. fake 模式在 `read_start` 把 `start_word` 装入 `tx_shift`。
3. fake 模式在 `read_done` 输出 `finish_word`。
4. hw 模式在 `hw_sample_valid` 到来时，要求 `finish_valid = 1`，否则报 `align_error`。

这样建模的好处是：

1. `read_start` 和 `read_done` 分别对应 burst 的开始和完成。
2. split-burst 的 head / tail 被明确映射到不同流水段。
3. fake 路径和真实硬件路径共享同样的 phase 定义。

## 7. testbench 改了什么

testbench 这次不只是跟着改参数，而是把 ADC 行为模型也改成了“本拍启动、本拍发 head、下一拍补 tail”。

当前 testbench 的行为是：

1. `posedge cnv_p` 时，准备“当前 sample 要输出的数据字”。
2. `negedge clk_p` 时，按 echoed-clock 规则推进串行位流。
3. 检查 `frame_start / read_start / read_done` 是否出现在 `0 / 15 / 6` 这些正确相位。

所以它现在验证的是：

1. RTL 的相位定义是否一致。
2. burst 长度是否还是 16 个系统周期。
3. 样本序列在这个新模型下是否还能连续对上。

## 8. 当前结论

这次修正之后，Day1-2 的默认实现已经符合下面这套理解：

1. `CNV` 周期可以取 `100 ns`。
2. 每个 sample 在当前拍发 head，在下一拍补完 tail。
3. `MSB_WAIT_CYCLES` 是 readiness 检查量，不是 burst 开始量。
4. 真正决定 burst 位置的是 `READ_START_CYCLES`。
5. 真正决定 burst 是否超界的是 `READ_HEAD_CYCLES` 和 `TCLKL_CYCLES` 的关系。

## 9. 还剩下的风险项

这次修正解决的是“时间模型错误”。

但下面这些仍然需要后续在板上或 ISE 里继续确认：

1. `tCLKL` 的精确定义和我们现在采用的边界是否完全一致。
2. 板级 `DCO` / `D` skew 是否会侵蚀当前 `8 ns` 余量。
3. 约束文件里 source-synchronous 的细节是否还需要继续收紧。
4. 你的实际板卡上 `CNV` 是差分 LVDS 还是单端 CMOS。

## 10. 当前建议

如果你接下来继续 review 代码，最值得盯住的不是“一个参数数字大不大”，而是下面这句话有没有被所有模块同时遵守：

```text
CNV(N) 启动 conversion(N)
cycle(N+1) 的 burst 读出 sample(N)
```

只要这一条保持一致，后面调参数、补约束、上板抓波形都会清楚很多。

补充一条当前板级前提：

1. 板上输入时钟现在按 `100 MHz` 处理。
2. Day1-2 内核仍然工作在 `250 MHz`。
3. 所以这次新增的是 clocking wrapper，不是把 burst 时序降到 `100 MHz`。
