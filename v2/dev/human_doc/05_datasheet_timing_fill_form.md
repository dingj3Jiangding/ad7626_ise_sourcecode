# AD7626 Datasheet 参数填表（Day1 下午）

用途：把实现 Day1 下午硬件接入所需的关键参数一次填全，避免边写代码边反复查手册。

## 1. 已确认逻辑项

1. 位序：MSB first。
2. dummy bit：无。
3. frame 间 D：0。
4. 每 frame 数据位数：16bit。
5. 转换触发：CNV 上升沿触发。
6. 采样边沿：主机在 `DCO` 上升沿采样 `D`，`D` 在 `DCO` 下降沿更新。

## 2. 时序参数数值（当前已整理）

说明：

1. 下表优先填写目前已经明确的 datasheet 数值。
2. 没在当前资料里看到 typ/max 的项先写 `N/A`。
3. Day1-2 RTL 默认值不一定等于 datasheet 极限值，而是偏保守的 bring-up 取值。

| 参数 | 含义 | Min | Typ | Max | 单位 | 备注 |
|---|---|---:|---:|---:|---|---|
| `tCYC` | CNV 周期 | 100 | N/A | 10000 | ns | Day1-2 现默认改为 100 ns |
| `tCNVH` | CNV 高电平宽度（上升沿触发后需回低） | 10 | N/A | 40 | ns | Day1-2 默认先用 20 ns |
| `tMSB` | CNV 到首位数据出现延迟 | 100 | N/A | 100 | ns | 当前直接按 100 ns 取值 |
| `tCLKL` | CNV 结束到 LSB 的时间 | 72 | N/A | 72 | ns | 当前仍作为风险边界继续核对 |
| `tSU(D)` | D 相对 DCO 下降沿建立时间 | N/A | N/A | N/A | ns | 当前资料未单独拆出，先用 `D`/`DCO` 关系理解 |
| `tH(D)` | D 相对 DCO 下降沿保持时间 | N/A | N/A | N/A | ns | 当前资料未单独拆出，后续补约束时再细化 |

## 2.1 当前 Day1-2 RTL 默认取值

按 `sys_clk_250 = 250 MHz`，当前 RTL 默认是：

1. `CNV_PERIOD_CYCLES = 25`，即 `100 ns`
2. `CNV_HIGH_CYCLES = 5`，即 `20 ns`
3. `MSB_WAIT_CYCLES = 25`，即 `100 ns`
4. `READ_START_CYCLES = 5`，即 `20 ns`
5. `READ_PULSE_CYCLES = 16`，即 `64 ns`
6. `TCLKL_CYCLES = 18`，即 `72 ns`

原因：

1. `sample(N)` 在 `cycle(N+1)` 的固定读窗里读出，不需要把 `tMSB` 和 16 个 `CLK` 塞进同一个 `tCYC`。
2. 从 `CNV(N)` 到 `cycle(N+1)` 读窗起点，一共经过：

```text
25 + 5 = 30 cycles = 120 ns
```

3. `120 ns` 已经大于 `tMSB = 100 ns`。
4. burst 结束点是：

```text
5 + 16 = 21 cycles = 84 ns
```

5. `tCLKL` 截止点是：

```text
5 + 18 = 23 cycles = 92 ns
```

6. 也就是当前默认值在截止边界前留出了 `8 ns` 余量。

## 3. 板级连接参数（请填写）

| 项目 | 结果 |
|---|---|
| ADC 数据线到 FPGA 引脚 |  |
| ADC DCO 到 FPGA 引脚 |  |
| 单端/差分连接方式 |  |
| IOSTANDARD |  |
| 相关 I/O Bank 电压(Vcco) |  |
| 端接方式（板上/FPGA 内） |  |

## 4. 约束策略草案（填写后给实现使用）

1. DCO 作为采样时钟的约束频率：
2. 数据口 input delay 参考边沿：下降沿。
3. setup/hold 预算（含板级走线偏差）:
4. 是否需要初版先不加 IODELAY，仅做最小 bring-up：

## 5. 完成判据

满足以下条件即可开始 Day1 下午 RTL 实现：

1. 第 2 节参数至少补齐 `tCYC`、`tCNVH`、`tMSB`、`tSU(D)`、`tH(D)`。
2. 第 3 节引脚与 IOSTANDARD 已确定。
3. 第 4 节约束策略至少有第一版结论。
