# Day1-2 Static Timing 报告分析

用途：单独记录 `ad7626_day1_2_board_top_100m` 当前这份 ISE static timing 报告到底说明了什么，失败点在哪，和 RTL 哪一段代码对应，以及下一步该怎么改。

对应对象：

1. `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top_100m.v`
2. `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`
3. `v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`
4. `v2/dev/constraints/ad7626_day1_2_board_top_template.ucf`

## 1. 结论先说

这份 timing 报告的主要问题只有一个：

`TS_ADC_DCO` 没过。

更准确地说：

1. 失败的是 `DCO` 域里的两个 setup path。
2. 这两个 path 都是 `IDDR2.Q0(data_rise_s)` 到 fabric 寄存器。
3. 它们都要求在 `4 ns` 时钟的半周期 `2 ns` 内完成。
4. 当前实际数据延迟已经大于 `2 ns`，所以这是结构问题，不是简单布线抖一下就能过。

一句话总结：

当前真正卡住实现的是 `data_rise_s` 这条 `rise -> fall` 半周期路径。

## 1.1 当前进展

在这份 timing 报告对应的代码基础上，当前 RTL 已经有两项新进展：

1. `serial_capture` 新增了 `read_start_align` 输入
2. `sys_clk -> DCO` 这一侧已经改成了 level request/ack 机制

这两项改动解决的是：

1. `read_start` 和 `bit_count_dco` 边界错位
2. request pulse 直接跨到 burst DCO 域容易丢的问题

但这两项改动没有解决的，是：

`IDDR2.Q0 -> negedge DCO fabric FF` 这条半周期路径。

所以当前阶段的状态是：

1. 功能对齐机制比以前更清楚了
2. 但 timing 主问题仍然存在

## 2. 报告整体怎么看

报告里三个时序组最重要：

1. `TS_SYS_CLK_100`
2. `TS_ADC_DCO`
3. `TS_u_clkgen_clk_250_dcm_s`

当前结果：

1. `TS_SYS_CLK_100`：`0 paths analyzed`
2. `TS_ADC_DCO`：`2 failing endpoints`
3. `TS_u_clkgen_clk_250_dcm_s`：`0 failing endpoints`

解释：

1. `sys_clk_100` 主要只进 `DCM`，所以这一组没有真正的同步寄存器路径被分析，这个结果本身不奇怪。
2. `clk_250_s` 这组内部逻辑是过的，但 slack 已经不算宽。
3. 真正没过的是 ADC source-synchronous 接收链。

## 3. 当前失败的 2 条路径

报告里失败端点是：

1. `u_board_top_core/u_serial_capture/shift_reg_dco_0`
2. `u_board_top_core/u_serial_capture/sample_word_dco_0`

对应的源都是：

`u_board_top_core/u_serial_capture/i_data_iddr2`

也就是 `IDDR2.Q0 -> data_rise_s`

### 3.1 第一条失败路径

```text
Source      : i_data_iddr2 (FF)
Destination : shift_reg_dco_0 (FF)
Requirement : 2.000 ns
Data Delay  : 2.075 ns
Slack       : -0.709 ns
Levels      : 0
```

关键信息：

1. `Levels of Logic = 0`
2. `Component delays alone exceeds constraint`

这两句很重要，意思是：

1. 这不是组合逻辑太深。
2. 就算没有任何 LUT，这条路径本身也已经太慢。
3. 根因是 `IDDR2` 输出到 fabric FF 的 `clock-to-Q + route + destination clocking` 已经超过半周期预算。

### 3.2 第二条失败路径

```text
Source      : i_data_iddr2 (FF)
Destination : sample_word_dco_0 (FF)
Requirement : 2.000 ns
Data Delay  : 2.060 ns
Slack       : -0.694 ns
Levels      : 0
```

这条和上一条本质一样：

1. 还是 `data_rise_s` 这条路径。
2. 还是半周期约束。
3. 还是 component delay 本身就超了。

所以这 2 个 failing endpoint 不是两个独立问题，而是同一个架构问题的两个表现。

## 4. 为什么这里要求是 2ns，不是 4ns

看当前 RTL：

```verilog
IDDR2 i_data_iddr2 (
  .Q0(data_rise_s),
  .C0(dco_clk_s),
  ...
);

always @(negedge dco_clk_s or negedge rstn) begin
  shift_reg_dco <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};
  ...
  sample_word_dco <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};
end
```

这表示：

1. `data_rise_s` 在 `posedge dco_clk_s` 从 `IDDR2.Q0` 出来。
2. 但 `shift_reg_dco` / `sample_word_dco` 在 `negedge dco_clk_s` 就要把它收进去。

对一个 `4 ns` 的 DCO 来说：

1. `posedge -> negedge` 只有 `2 ns`
2. 所以 ISE 报告里的 requirement 就是 `2.000 ns`

也就是说，当前 RTL 本质上造出了一个：

`IDDR2 rising-edge launch -> fabric falling-edge capture`

的半周期路径。

## 5. 对照到当前代码，问题具体在哪

对应文件：

`v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`

关键片段：

```verilog
.Q0 (data_rise_s)
```

和：

```verilog
always @(negedge dco_clk_s or negedge rstn) begin
  ...
  shift_reg_dco <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};
  ...
  sample_word_dco <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};
end
```

所以当前没过 timing 的根因不是：

1. `capture_req_sys`
2. `capture_active_dco`
3. `capture_ack_toggle_dco`
4. `sample_toggle_dco -> sys_clk` 这条 CDC

真正的根因是：

`data_rise_s` 被要求在同一个 DCO 周期的另一半边沿就进入 fabric 寄存器。`

## 6. 报告里的 clock skew 说明了什么

报告里失败路径还有一项：

```text
Clock Path Skew: -0.599 ns
```

这说明：

1. 这条半周期路径不光数据本身慢。
2. 源和目的寄存器的时钟到达时间还对你不利。
3. 所以有效预算比理想的 `2 ns` 更紧。

但即使先不看 skew，数据路径本身也已经：

```text
2.075 ns > 2.000 ns
2.060 ns > 2.000 ns
```

所以这不是“skew 太差”单独造成的；skew 只是把本来就不够的路径进一步拉坏。

## 7. `capture_active_dco` 这些新逻辑是不是主因

不是主因。

报告里确实出现了几条和 `capture_active_dco`、`bit_count_dco` 相关的 near-critical path，但它们都过了：

1. `capture_active_dco -> sample_word_dco_14`：`Slack 0.805 ns`
2. `bit_count_dco_2 -> sample_word_dco_14`：`Slack 0.744 ns`
3. `bit_count_dco_3 -> sample_word_dco_14`：`Slack 0.960 ns`

这些路径属于：

`falling-edge -> falling-edge`

的整周期 `4 ns` 路径。

它们说明：

1. 新加的 request/ack 状态机会增加一些 DCO 域控制逻辑负担。
2. 但当前真正让设计 fail 的，还是前面的 `rise -> fall` 半周期路径。

## 8. debug 端口会不会是根因

不能把根因归结为 debug 端口。

原因很简单：

1. 报告已经明确写了 `Levels of Logic = 0`
2. 还写了 `Component delays alone exceeds constraint`

这说明即使把 debug fanout 全去掉，当前结构也未必能闭上。

更准确的说法是：

1. debug 端口可能会轻微影响命名和布线。
2. 但它不是这次 fail 的主因。
3. 主因仍然是半周期结构本身太紧。

## 9. 现在应该怎么改

优先级最高的建议只有一条：

### 9.1 先消掉 `IDDR2.Q0 -> negedge DCO fabric FF` 这条半周期路径

也就是不要再让：

1. `data_rise_s` 在 `posedge dco_clk_s` 出来
2. 然后在同周期 `negedge dco_clk_s` 进入 `shift_reg_dco/sample_word_dco`

更合理的方向是：

1. 让 `IDDR2.Q0` 采到的值在下一次同边沿被消费
2. 或者把整个 DCO 域组字逻辑统一到同一边沿
3. 总之把这条路径从 `2 ns` 半周期路径变成 `4 ns` 整周期路径

一句话总结：

要改的是接收架构，不是单纯约束。

### 9.2 当前不建议优先做的事

下面这些都不是第一优先级：

1. 先去调 UCF 约束
2. 先去压 placement
3. 先删 request/ack 逻辑
4. 先删 debug 端口

这些动作可能会带来一点点改善，但都没有击中主因。

### 9.3 结合当前进度，下一步最合理的方向

由于 `read_start_align` 对齐链和 request/ack 调试口已经接进来了，下一步建议不要再在现有 `negedge dco_clk_s` 结构上做小修小补，而是直接重构：

1. 保留当前 `read_start_align` 的字边界控制思路
2. 保留当前 `sample_toggle_dco -> sys_clk` 的返回思路
3. 重写 DCO 域组字边沿关系，消掉 `Q0 -> negedge` 半周期路径

也就是说，当前真正应该动刀的部分是：

`shift_reg_dco / sample_word_dco` 的接收边沿，而不是 request/ack 外围逻辑。

### 9.4 当前已经加入的实验实现

基于上面的方向，当前 `ad7626_s6_serial_capture.v` 已经加入一个实验参数：

```verilog
parameter integer FULL_CYCLE_CAPTURE = 1
```

含义：

1. `0`：切回 `IDDR2.Q0 -> negedge dco_clk_s` 的 half-cycle 路径
2. `1`：默认采用 `posedge dco_clk_s` 的 full-cycle 路径，并通过 `capture_arm_dco` 延后一拍消费 `data_rise_s`

这个实验分支想验证的不是功能花样，而是一个很具体的问题：

`能不能把 timing fail 的 2ns 半周期路径，改造成 4ns 整周期路径。`

### 9.5 这个实验当前证明了什么，没证明什么

它当前能证明的是：

1. `IDDR2.Q0` 的消费边沿确实可以改成同边沿
2. `data_rise_s -> shift_reg_dco` 可以从 `rise -> fall` 改成 `rise -> rise`
3. 模块级逻辑可以用额外一拍把数据正确推进到 `sample_word_dco`

但它当前还没有证明的是：

1. 现有顶层 ADC burst 时序不改也能直接兼容
2. `board_top` 在真实硬件上已经不需要别的协议调整

原因是当前 full-cycle 实验分支有一个明确代价：

1. 第 16 个 bit 在第 16 个 DCO 上升沿只是先进入 `IDDR2.Q0`
2. 还需要第 17 个 DCO 上升沿，才能把最后 1bit flush 进 `shift_reg_dco/sample_word_dco`

所以这个模式目前是“验证时序架构”的实验，不是已经完成的顶层硬件修复。

### 9.6 用于验证这个实验的 simulation TB

当前已经新增模块级 testbench：

`v2/dev/tb/Day1-2/tb_ad7626_s6_serial_capture.v`

这个 TB 做了三件核心事情：

1. 例化 `FULL_CYCLE_CAPTURE=1`
2. 发送多组 16bit 测试字
3. 在最后补 1 个 flush edge，检查 DCO 域和 sys 域输出都正确

因此这个 TB 适合回答的问题是：

`full-cycle 这个想法在模块级功能上是否自洽。`

它暂时不回答的问题是：

`现有 board_top + 真实 ADC burst 在不改外部时序的情况下是否已经完全兼容。`

另外，当前也已经把顶层实验 TB 接上：

`v2/dev/tb/Day1-2/tb_ad7626_day1_2_board_top.v`

这个顶层 TB 的做法是：

1. 例化 `FULL_CYCLE_CAPTURE=1`
2. 把 `READ_PULSE_CYCLES` 从 `16` 调整为 `17`
3. 让第 17 个 DCO pulse 充当 flush edge

所以这个 top TB 适合做的是：

`验证 full-cycle 实验在顶层时序组织下能不能跑通。`

它仍然代表的是“实验性 top-level sim 配置”，不是已经确认真实 ADC 协议也必须改成 17 pulse。

## 10. 第二个需要注意的问题：`clk_250_s` 域已经很紧

虽然 `TS_u_clkgen_clk_250_dcm_s` 当前是过的，但报告里已经出现了几条非常紧的 near-critical path：

1. `u_timing_gen/frame_start -> start_word_r_12`：`Slack 0.364 ns`
2. `u_timing_gen/frame_start -> tx_word_r_15`：`Slack 0.389 ns`
3. `u_timing_gen/cnv -> i_cnv_oddr2`：`Slack 0.393 ns`

这三条路径现在还不是 timing error，但已经说明：

1. `250 MHz` 内核的 sys_clk 域 margin 不宽。
2. 如果后面再继续往 `board_top` 里加控制逻辑、debug 或比较器，很容易把这几条路径推到 fail。

### 10.1 `frame_start` 高扇出路径

前两条路径的共同点是：

1. 源都是 `u_timing_gen/frame_start`
2. 都是 `Levels of Logic = 0`
3. 都是 route delay 占大头

例如：

```text
frame_start -> start_word_r_12
Data Path Delay = 3.564 ns
其中 net delay = 2.726 ns
```

这说明问题不是组合逻辑复杂，而是：

`frame_start` 这个控制信号扇出较高，跨区域布线太长。`

### 10.2 `cnv -> ODDR2` 半周期路径

第三条路径：

```text
u_timing_gen/cnv -> i_cnv_oddr2
Requirement = 2.000 ns
Data Path Delay = 1.911 ns
Slack = 0.393 ns
```

它和主失败点一样，也属于：

`posedge -> negedge`

半周期路径，只不过它目前还勉强过了。

这说明：

1. `board_top` 里不只有 `serial_capture` 在吃半周期预算。
2. `ODDR2` 驱动 `CNV` 这条路径也已经比较紧。

### 10.3 这个“第二个问题”应该怎么理解

它不是当前 implementation fail 的直接原因。

当前真正导致 `1 constraint not met` 的，仍然是：

`TS_ADC_DCO` 的 2 条失败路径。`

但这组 near-critical path 告诉你：

1. 即使把 `serial_capture` 的主问题修掉，
2. `clk_250_s` 域也未必还有很多余量可以随便消耗。

所以后续改 RTL 时，最好顺手注意两件事：

1. 不要让 `frame_start/read_start/cnv` 这类控制信号继续增加大扇出。
2. 尽量避免再新增 `sys_clk_250` 域里的半周期控制路径。

### 10.4 这部分后续建议

如果后面 `TS_ADC_DCO` 修好之后，`clk_250_s` 域开始变成新的瓶颈，优先考虑：

1. 给 `frame_start` 相关控制做本地寄存或扇出复制。
2. 重新整理 `board_top` 里 `start_word_r / finish_word_r / tx_word_r` 的控制更新关系。
3. 检查 `cnv` 到 `ODDR2` 是否能进一步本地化，减少 route。

一句话总结：

第二个问题不是“又一个已经 fail 的错误”，而是：

`250 MHz` 域已有多条只剩 `0.3~0.4 ns` 裕量的路径，后续改动要非常克制。`

## 11. 这份报告给出的工程判断

当前工程状态可以总结成三句话：

1. `100 MHz -> 250 MHz` 的 wrapper 架构本身是通的。
2. `250 MHz sys_clk` 域大部分逻辑能过，但 margin 不算宽。
3. 当前实现真正卡死在 `ad7626_s6_serial_capture` 的半周期接收路径。

所以如果现在要继续推进，正确顺序应该是：

1. 先重构 `serial_capture` 的 DCO 域采样/组字边沿关系。
2. 再重新看 `TS_ADC_DCO`。
3. 最后再处理 `clk_250_s` 域那些只有 `0.3~0.4 ns` slack 的 near-critical path。

## 12. 最简总结

这次 static timing 报告说明的不是“整个设计都不行”，而是：

`当前 AD7626 接收核把 IDDR2 的上升沿采样结果，要求在同一个 DCO 周期的下降沿就进入 fabric 寄存器，这条 2ns 半周期路径在 Spartan-6 上过不去。`

因此下一步最该改的模块就是：

`v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`
