# AD7626 Datasheet 参数填表（Day1 下午）

用途：把实现 Day1 下午硬件接入所需的关键参数一次填全，避免边写代码边反复查手册。

## 1. 已确认逻辑项

1. 位序：MSB first。
2. dummy bit：无。
3. frame 间 D：0。
4. 每 frame 数据位数：16bit。
5. 转换触发：CNV 上升沿触发。
6. 采样边沿：DCO 下降沿采样 D。

## 2. 时序参数数值（请填写）

请从 datasheet 填写 min/typ/max（若某列无值可填 N/A）。

| 参数 | 含义 | Min | Typ | Max | 单位 | 备注 |
|---|---|---:|---:|---:|---|---|
| `tCYC` | CNV 周期 |  |  |  |  |  |
| `tCNVH` | CNV 高电平宽度（上升沿触发后需回低） |  |  |  |  |  |
| `tMSB` | CNV 到首位数据出现延迟 |  |  |  |  |  |
| `tCLKL` | CNV 结束到 LSB 的时间 |  |  |  |  |  |
| `tSU(D)` | D 相对 DCO 下降沿建立时间 |  |  |  |  |  |
| `tH(D)` | D 相对 DCO 下降沿保持时间 |  |  |  |  |  |

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
