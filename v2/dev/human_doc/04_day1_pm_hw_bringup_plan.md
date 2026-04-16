# Day1 下午任务说明（硬件接入第一阶段）

对应阶段：把 Day1 上午的纯数字 loopback，升级成可以真实上板验证的 AD7626 echoed-clock 最小板级链路。

## 1. 本阶段目标

这一阶段的目标不是做完整量产方案，而是先做出一个“真正按接口协议工作的第一版板级实现”。

完成后应具备下面闭环：

1. FPGA 产生 `CNV`。
2. FPGA 产生 16 个 `CLK` burst。
3. ADC 返回 `DCO` 和 `D`。
4. FPGA 用 `DCO` 采样 `D`，收成 16bit。
5. 系统侧能看到 `sample_valid`、`sample_data`、`sample_count`。

## 2. 本阶段完成定义（DoD）

满足以下条件即可认为 Day1 下午完成：

1. 板上能观测到稳定的 `CNV` 周期。
2. 板上能观测到只在 burst 窗口内活动的 `CLK`。
3. ADC 能返回 `DCO` burst。
4. `sample_valid` 周期出现。
5. `sample_count` 持续递增。
6. `align_error` 不能常态为 1。
7. 代码保留 fake 模式，便于回退。

## 3. 当前实现方案

当前 Day1-2 已经采用下面这套结构：

1. `ad7626_day1_2_timing_gen`
   负责生成 `cnv`、`clk_gate`、`frame_start`、`read_start`、`read_done`。
2. `ODDR2 + OBUFDS`
   负责把 `sys_clk_250` 变成差分 `CLK±` burst 与差分 `CNV±`。
3. `ad7626_s6_serial_capture`
   负责用 `DCO` 做接收时钟，按 16bit 组帧。
4. `ad7626_day1_2_board_top`
   作为 `250 MHz` 内核，负责把发送链、接收链、fake/hw 模式和调试导出拼起来。
5. `ad7626_day1_2_board_top_100m`
   作为当前板级外层顶层，接收 `100 MHz` 板时钟，在 FPGA 内部生出 `250 MHz` 再驱动内核。

## 4. 为什么这一步直接做 DCO 域采样

AD7626 echoed-clock 模式的关键规则是：

1. `D` 在 `DCO` 下降沿更新。
2. 主机应在 `DCO` 上升沿采样 `D`。
3. `CLK` 空闲时必须保持低。

所以本阶段如果还继续用“把 `D` 先同步到系统时钟域”的占位法，250 MHz 下风险太高，也不再符合你现在要做“可上板验证”的要求。

因此本阶段直接做：

1. 差分输入缓冲
2. `IDDR2` 边界采样
3. DCO 域 16bit 组帧
4. 轻量跨域回 `sys_clk_250`

## 5. 当前 bring-up 参数与评估

## 5.1 你当前一直在讨论的参数

目前我们一直围绕下面这组数值讨论：

1. `tCYC = 200 ns`
2. `tCNVH = 20 ns`
3. `tMSB = 100 ns`
4. `tCLK = 4 ns`
5. `tCLKL = 60 ns`

## 5.2 这组数值里真正有问题的地方

之前最需要警惕的，其实不是某一个单独参数，而是“时序关系理解错了”。

旧理解是：

1. 在同一个 `tCYC` 里先等 `tMSB`
2. 再把 16 个 `CLK` 全部发完

按这个错误模型，当然会得到：

```text
16 x 4 ns = 64 ns
```

以及：

```text
100 ns + 64 ns = 164 ns
```

然后会进一步推到“`200 ns` 只剩 `36 ns` 余量”。

但 AD7626 echoed-clock 满速工作时，更合理的理解应该是：

1. `CNV(N)` 启动 conversion `N`
2. `cycle(N+1)` 里的 burst 读 sample `N`
3. 只要 burst 结束时间满足 `tCLKL` 边界即可

也就是说，sample read 可以和下一拍 conversion/acquisition 重叠。

## 5.3 现行默认参数检查

Day1-2 现在的默认值改成：

| 项目 | 周期数 | 时间 |
|---|---:|---:|
| `CNV_PERIOD_CYCLES` | 25 | 100 ns |
| `CNV_HIGH_CYCLES` | 5 | 20 ns |
| `MSB_WAIT_CYCLES` | 15 | 60 ns |
| `READ_START_CYCLES` | 15 | 60 ns |
| `READ_PULSE_CYCLES` | 16 | 64 ns |
| `TCLKL_CYCLES` | 10 | 40 ns |

对应检查有两条：

第一条，当前样本在本拍读窗开始前是否已经 ready：

```text
READ_START_CYCLES
= 15 cycles
= 60 ns
```

因为：

```text
60 ns >= tMSB = 60 ns
```

第二条，burst 是否在 `tCLKL` 边界前结束：

```text
READ_HEAD_CYCLES = CNV_PERIOD_CYCLES - READ_START_CYCLES
                 = 25 - 15
                 = 10 cycles
                 = 40 ns
```

而截止边界是：

```text
TCLKL_CYCLES
= 10 cycles
= 40 ns
```

所以：

```text
40 ns <= 40 ns
```

也就是当前默认值满足我们现在采用的这套时序假设。

## 5.4 当前我对参数的结论

现在建议把下面这组值作为 Day1-2 默认：

1. `tCYC = 100 ns`
2. `tCNVH = 20 ns`
3. `tMSB = 100 ns`
4. `tCLK = 4 ns`
5. `read_start = 20 ns`
6. `tCLKL = 72 ns`

也就是说：

1. `tCNVH` 没问题。
2. `tMSB` 没问题。
3. `tCLK = 4 ns` 没问题。
4. 关键不是把 `tCYC` 做大，而是把 burst 放在“下一拍的固定读窗”。
5. 如果后面板测想加余量，可以再放宽 `READ_START_CYCLES` 或 `CNV_PERIOD_CYCLES`。

## 6. 当前 I/O 电平标准结论

当前仍采用你之前从参考工程 `system_constr.xdc` 提取出来的电平标准，作为 first bring-up 检查依据：

1. `dco_p/n`：`LVDS_25`
2. `d_p/n`：`LVDS_25`
3. `clk_p/n`：`LVDS_25`
4. `cnv_p/n`：`LVDS_25`
5. 板级使能脚如果有：`LVCMOS25`

说明：

1. 这是当前 Day1-2 RTL 的默认假设。
2. 如果你的板子上 `CNV` 其实是单端 2.5 V CMOS，而不是差分 LVDS，就需要再改 top 和约束模板。

## 7. 当前还缺什么外部条件

除了 RTL 本身，Day1-2 还依赖下面两项你来补板级信息：

1. `sys_clk_100` 的实际引脚与电平标准
2. 实际引脚 `LOC`

第 1 点说明：

现在已经按你板上的原生 `100 MHz` 时钟补了 wrapper。  
当前推荐综合顶层是 `ad7626_day1_2_board_top_100m`，它会在 FPGA 内部生成 `250 MHz` 的读数内核时钟。

第 2 点说明：

我已经补了一个 `UCF` 模板：

`v2/dev/constraints/ad7626_day1_2_board_top_template.ucf`

你只需要按原理图补：

1. `sys_clk_100`
2. `dco_p/n`
3. `d_p/n`
4. `clk_p/n`
5. `cnv_p/n`

## 8. 建议的上板检查顺序

建议先按这个顺序排查：

1. 看 `sys_clk_250` 是否正确。
   对当前板子来说，这一步应改成先看 `sys_clk_100` 是否正确，再看内部 `250 MHz` 是否锁定。
2. 看 `CNV` 周期是否正确。
3. 看 `CLK` 是否只在 burst 窗口活动、空闲保持低。
4. 看 ADC 是否回 `DCO`。
5. 看 `D` 是否在 burst 期间有活动。
6. 看 `sample_valid`。
7. 看 `sample_count`。

## 9. 典型失败现象与快速定位

1. 没有 `DCO`
   大概率先查 ADC 模式脚、供电、参考模式、板级连线。
2. `DCO` 有，但 `sample_valid` 不稳定
   优先查 DCO 接收路径和约束。
3. `sample_valid` 有，但 `align_error` 常亮
   优先查 burst 长度、帧边界、是否丢了某个 DCO 边沿。
4. fake 模式正常，hw 模式异常
   说明系统侧计数框架基本没问题，重点回到板级 I/O 与 ADC 接口时序。

## 10. 结论

Day1 下午的核心不是“随便让板上有点波形”，而是：

1. 先做一个最小但真实的 echoed-clock 板级版本。
2. 默认参数偏保守，优先保成功率。
3. 把 `tCYC = 200 ns` 这个风险点先避开。
