# ad7626_day1_2_board_top_100m 说明

对应源码：

1. `v2/dev/rtl/Day1-2/ad7626_day1_2_clkgen_100m_to_250m.v`
2. `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top_100m.v`

## 1. 为什么要新增这个 wrapper

你现在确认板上的原生系统时钟是 `100 MHz`。

这会带来一个直接约束：

1. 当前 Day1-2 内核的 `ODDR2` 结构里，送给 ADC 的 `CLK` 频率就是内部系统时钟频率。
2. 如果直接把内核时钟改成 `100 MHz`，那么 ADC 读时钟也只剩 `100 MHz`。
3. 这样 16bit burst 需要：

```text
16 x 10 ns = 160 ns
```

4. 这和当前采用的 `tCLKL = 72 ns` 约束明显冲突。

所以不能做的事是：

1. 直接把 `sys_clk_250` 改成 `sys_clk_100`
2. 然后只改参数

正确做法是：

1. 板上输入时钟是 `100 MHz`
2. FPGA 内部先生成 `250 MHz`
3. Day1-2 原有读数内核继续工作在 `250 MHz`

## 2. 新的层次结构

现在层次变成：

```text
sys_clk_100 (board oscillator)
  -> ad7626_day1_2_clkgen_100m_to_250m
  -> clk_250_out
  -> ad7626_day1_2_board_top
  -> CLK± / CNV± / capture path
```

也就是说：

1. `ad7626_day1_2_board_top.v` 继续是 `250 MHz` 内核。
2. `ad7626_day1_2_board_top_100m.v` 才是当前更适合上板的外层顶层。

## 3. `ad7626_day1_2_clkgen_100m_to_250m` 做了什么

它的任务很单一：

1. 接收板上的 `100 MHz` 单端时钟
2. 用 `DCM_SP` 生成 `250 MHz`
3. 用 `BUFG` 把 `250 MHz` 分发到 fabric
4. 输出 `locked`

当前参数是：

```text
100 MHz x 5 / 2 = 250 MHz
```

在代码里对应：

```verilog
.CLKFX_MULTIPLY(5)
.CLKFX_DIVIDE(2)
```

## 4. `ad7626_day1_2_board_top_100m` 做了什么

这个 wrapper 做两件事：

1. 实例化 `100 MHz -> 250 MHz` 时钟生成模块
2. 用生成出来的 `clk_250_s` 去驱动原来的 Day1-2 内核

关键点：

1. wrapper 的输入端口是 `sys_clk_100`
2. 内核收到的仍然是 `sys_clk_250`
3. `core_rstn_s = rstn & clkgen_locked_dbg`

第 3 点的含义是：

1. 在时钟还没锁定前，不让内核开始跑
2. 避免 `CNV` / `CLK` / 接收链在不稳定时钟下误动作

## 5. 这次“重新调整时序”到底改了什么

这次并没有改 Day1-2 内核的核心时间参数：

| 参数 | 值 |
|---|---:|
| `CNV_PERIOD_CYCLES` | 25 |
| `CNV_HIGH_CYCLES` | 5 |
| `MSB_WAIT_CYCLES` | 15 |
| `READ_START_CYCLES` | 15 |
| `READ_PULSE_CYCLES` | 16 |
| `TCLKL_CYCLES` | 10 |

原因很直接：

1. 这些参数本来就是建立在“内核工作在 `250 MHz`”这个前提上。
2. 你现在变的是板上输入时钟来源，不是 ADC burst 的目标频率。
3. 现在内核时序已经改成 split-burst：
   - 当前周期末尾 `10` 个 clock
   - 下一周期开头 `6` 个 clock
4. 所以真正要改的是 clocking architecture，不是把 burst 降到 `100 MHz`。

## 6. UCF 现在应该怎么理解

`ad7626_day1_2_board_top_template.ucf` 现在的口径是：

1. 顶层输入时钟约束对象是 `sys_clk_100`
2. 周期约束是 `10 ns`
3. `DCO` 仍按 `4 ns` 的 burst clock 来约束接收路径

这是因为：

1. 板上进来的时钟确实是 `100 MHz`
2. ADC 返回的 `DCO` 仍然对应 `250 MHz` burst

## 7. 当前建议的综合顶层

如果你现在要在 ISE 里建工程，建议把顶层切到：

```text
ad7626_day1_2_board_top_100m
```

而不是直接用：

```text
ad7626_day1_2_board_top
```

因为后者默认假设外部已经直接给了一个干净的 `250 MHz` 时钟。

## 8. 当前剩余风险

这次改动解决的是“板上只有 100 MHz 时钟怎么办”。

但还有两件事需要后续在 ISE / 上板上确认：

1. 这颗 Spartan-6、这个 speed grade 下，`DCM_SP CLKFX = 250 MHz` 的实现质量是否满足你的板级裕量要求。
2. 如果 DCM 方案在实现或抖动上不理想，再切到 `PLL_ADV` 版本。

当前先用 DCM 的原因是：

1. 结构简单
2. 目标明确
3. 对当前 bring-up 足够直接
