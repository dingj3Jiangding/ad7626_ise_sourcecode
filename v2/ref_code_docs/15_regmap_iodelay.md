# 15 IODELAY 寄存器文档解读

源文件：docs/regmap/adi_regmap_iodelay.txt

## 1. 这个文档在驱动中的作用

它定义每一路 delay tap 的寄存器接口，用于输入数据对齐和采样裕量调优。

## 2. 关键片段 1：前两路控制

```text
REG 0x00 REG_DELAY_CONTROL_0
[4:0] DELAY_CONTROL_IO_0

REG 0x01 REG_DELAY_CONTROL_1
[4:0] DELAY_CONTROL_IO_1
```

解释：

- 每个寄存器控制一路 I/O delay tap 值。
- 写入后可读回验证是否生效。

## 3. 关键片段 2：后续通道扩展

```text
REG 0x02 REG_*
...
REG 0x0F REG_DELAY_CONTROL_F
```

解释：

- 寄存器数量与具体接口线数有关。
- 采样链通常至少会覆盖数据线和帧线。

## 4. 异常语义

文档中给出：

- 若 delay controller 未锁定，读回可能是 0xFFFFFFFF。

这意味着：

1. 调 tap 前必须先确认 delay 参考时钟正常。
2. 读回全 F 时不要盲目继续扫点。

## 5. 驱动建议

1. 提供 iodelay 扫描模式（例如从 0 到最大 tap）。
2. 对每个 tap 统计稳定样本数，选择中间裕量点。
3. 保存最终 tap 到配置，作为下次启动初值。

## 6. 调试优先级

1. 先确保 delay 控制可读写。
2. 再做 tap 扫描与误码统计。
3. 最后固定最优 tap 进入常规采样流程。
