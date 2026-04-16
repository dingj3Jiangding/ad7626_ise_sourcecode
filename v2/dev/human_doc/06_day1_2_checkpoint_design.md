# Day1-2 Checkpoint 设计说明（实现版）

用途：说明 Day1-2 现在到底实现什么、为什么这样实现、以及哪些参数是当前推荐的上板 bring-up 默认值。

对应源码：

1. `v2/dev/rtl/Day1-2/ad7626_day1_2_timing_gen.v`
2. `v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`
3. `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`
4. `v2/dev/constraints/ad7626_day1_2_board_top_template.ucf`
5. `v2/dev/tb/Day1-2/tb_ad7626_day1_2_board_top.v`

## 1. 本 checkpoint 现在做的事

这一步不再是旧版文档里那个“先把板级数据做两级同步看看有没有活动”的占位方案了。

现在的 Day1-2 已经升级成真正符合 AD7626 echoed-clock 接口分工的最小板级实现：

1. FPGA 用 `sys_clk_250` 产生 `CNV` 与 16 个 `CLK` burst。
2. ADC 返回 `DCO` 与 `D`。
3. FPGA 用 `DCO` 做 source-synchronous 接收。
4. 接收到的 16bit 样本再跨回 `sys_clk_250` 域。
5. 顶层仍保留 fake 模式，便于回退。

一句话：

Day1-2 的目标已经从“看生命体征”提升到“能按 echoed-clock 规则真实收数”。

## 2. 为什么不能再用旧版“两级同步占位法”

AD7626 echoed-clock 模式里：

1. `D` 是跟着 `DCO` 变化的。
2. `D` 在 `DCO` 下降沿更新。
3. 主机应在 `DCO` 上升沿采样。

因此 `D` 不是普通的 fabric-synchronous 输入。

如果直接：

```verilog
always @(posedge sys_clk_250)
```

去采 `D`，那采样边沿与数据有效窗没有固定相位关系，250 MHz 下风险很高。  
所以 Day1-2 这里直接做了最小可用的 source-synchronous 接收，而不是继续拖到 Day2。

## 3. 当前推荐结构

```text
sys_clk_250
  -> ad7626_day1_2_timing_gen
  -> ODDR2 + OBUFDS
  -> CNV± / CLK±

ADC
  -> DCO± / D±

DCO domain
  -> IBUFGDS / IBUFDS
  -> IDDR2
  -> 16-bit shift
  -> sample_toggle

sys_clk_250 domain
  -> toggle sync
  -> sample_valid / sample_data / sample_count
```

这套结构已经对应上 datasheet 里最关键的三条规则：

1. `CNV` 上升沿启动转换。
2. `CLK` 只在 burst 窗口里发，空闲时保持低。
3. `D` 用 `DCO` 做接收时钟。

## 4. 当前默认参数为什么这样选

当前默认值按 `sys_clk_250 = 250 MHz` 设计，也就是一个时钟周期 `4 ns`。

| 项目 | 周期数 | 时间 |
|---|---:|---:|
| `CNV_PERIOD_CYCLES` | 25 | 100 ns |
| `CNV_HIGH_CYCLES` | 5 | 20 ns |
| `MSB_WAIT_CYCLES` | 15 | 60 ns |
| `READ_START_CYCLES` | 15 | 60 ns |
| `READ_PULSE_CYCLES` | 16 | 64 ns |
| `TCLKL_CYCLES` | 10 | 40 ns |

这样选的原因：

1. `CNV_HIGH = 20 ns` 落在 `tCNVH = 10 ns ~ 40 ns` 允许范围内。
2. `sample(N)` 在 `cycle(N)` 的 `READ_START` 就开始读 head，所以等待时间是：

```text
READ_START_CYCLES
= 15 cycles
= 60 ns
```

3. `60 ns` 已经等于当前采用的 `tMSB = 60 ns`。
4. 当前周期 head 长度是：

```text
READ_HEAD_CYCLES = 25 - 15 = 10 cycles = 40 ns
```

5. `tCLKL` 截止点按当前默认值是：

```text
TCLKL_CYCLES = 10 cycles = 40 ns
```

6. 也就是当前周期 head 正好贴着 `tCLKL` 边界结束，剩下 `6` 个 clock 放到下一周期头部。

因此：

1. 之前把 burst 做成单段窗口的理解是错误的。
2. 修正成“本拍发 head、下一拍补 tail”后，`tCYC = 100 ns` 是合理的默认值。
3. 如果后面板测想留更大余量，可以再把 `READ_START_CYCLES` 或 `CNV_PERIOD_CYCLES` 调大。

## 5. 这个 checkpoint 的边界

本阶段已经做：

1. 真正的 DCO 域接收。
2. 差分 LVDS 输入输出原语。
3. fake/hw 双模式保留。
4. 上板调试信号导出。
5. UCF 模板占位。

本阶段仍然不做：

1. IODELAY 扫描。
2. 更完整的异步 FIFO。
3. AXI / DMA / CPU 配置面。
4. 板级 PLL/DCM 具体实现。

第 4 点特别说明：

当前顶层假设你已经有一个稳定的 `sys_clk_250`。  
如果你板上的晶振不是 250 MHz，需要在更外层先用 DCM/PLL 生成这个时钟，再接入本 top。

## 6. 当前实现里的关键模块职责

## 6.1 `ad7626_day1_2_timing_gen`

职责：

1. 生成 `cnv`
2. 生成 `clk_gate`
3. 生成 `frame_start`
4. 生成 `read_start`
5. 生成 `read_done`

你可以把它理解成：

“在每个 sample 周期里，同时安排当前拍的 `CNV`，以及上一拍结果的固定读窗”。

## 6.2 `ad7626_s6_serial_capture`

职责：

1. 用 `IBUFGDS` 接收 `DCO±`
2. 用 `IBUFDS` 接收 `D±`
3. 用 `IDDR2` 在 `DCO` 上升沿把 `D` 打进 IO 边界
4. 在 DCO 域拼成 16bit
5. 用 toggle 把完整样本送回 `sys_clk_250`

这里最重要的一点是：

接收位边沿不再由 `sys_clk_250` 决定，而由 ADC 返回的 `DCO` 决定。

## 6.3 `ad7626_day1_2_board_top`

职责：

1. 组合 timing generator 与 serial capture
2. 用 `ODDR2 + OBUFDS` 输出差分 `CLK±`
3. 用 `ODDR2 + OBUFDS` 输出差分 `CNV±`
4. 保留 fake 模式
5. 输出 `sample_valid / sample_data / sample_count / align_error`

## 7. 上板时建议先看什么

建议按这个顺序看示波器或 ILA：

1. `cnv_p/n`
2. `clk_p/n`
3. `dco_p/n`
4. `d_p/n`
5. `frame_start_dbg`
6. `read_start_dbg`
7. `clk_gate_dbg`
8. `sample_valid`
9. `sample_count`

推荐判断逻辑：

1. 如果 `CNV` 和 `CLK` 都不对，先查 `sys_clk_250` 和 timing 参数。
2. 如果 `CNV` / `CLK` 对，但没有 `DCO`，先查 ADC 模式脚、供电、参考源和板级连接。
3. 如果有 `DCO` / `D`，但 `sample_valid` 不稳定，再查接收相位和约束。

补一条最关键的理解：

1. `CNV(N)` 启动 conversion `N`。
2. `cycle(N+1)` 里的 burst 读出的是 sample `N`。
3. 这不是“多等了一拍”，而是 AD7626 满速 echoed-clock 模式本来就允许的重叠关系。

## 8. 当前参数还剩什么风险

目前最需要继续确认的，不是 `tCNVH`，而是下面这两件事：

1. `tCLKL` 的精确定义边界
2. `D` 相对 `DCO` 的板级总 skew 预算

对当前代码的影响：

1. 代码默认值已经和当前这套重叠读数模型对齐。
2. 但 `OFFSET IN` 之类更严格的时序约束，还不能算最终版。
3. 如果后面确认 `tCLKL` 的解释和我们现在理解不同，再回头收紧 `CNV_PERIOD_CYCLES` 即可。

## 9. 通过标准

Day1-2 通过时，至少应满足：

1. `CNV` 周期稳定。
2. `CLK` 只在 burst 窗口内跳变，空闲保持低。
3. 板上能看到 `DCO` 跟随 burst 返回。
4. `sample_valid` 周期性出现。
5. `sample_count` 持续递增。
6. `align_error` 不持续拉高。

## 10. 结论

当前 Day1-2 不再是“占位输入版”，而是：

1. 一个最小但真实的 echoed-clock 板级收发版本。
2. 默认参数偏保守，优先追求 bring-up 成功率。
3. 还需要你后续补板级 `LOC` 和系统时钟生成外壳。
