# 13 PWM 寄存器文档解读

源文件：docs/regmap/adi_regmap_pwm_gen.txt

## 1. 这个文档在驱动中的作用

PWM 模块负责输出 cnv 和 clk_gate 的节拍，是采样速率和相位关系的核心控制器。

## 2. 关键片段 1：复位与配置加载

```text
REG 0x0004 REG_RSTN
[1] LOAD_CONFIG
[0] RESET
```

解释：

- 先写周期/宽度等配置寄存器。
- 再触发 LOAD_CONFIG 让配置生效。

## 3. 关键片段 2：Pulse0（通常接 CNV）

```text
REG 0x0010 REG_PULSE_0_PERIOD
REG 0x0011 REG_PULSE_0_WIDTH
REG 0x0012 REG_PULSE_0_OFFSET
```

解释：

- PERIOD 定义采样节拍。
- WIDTH 定义高电平持续时间。
- OFFSET 用于和其它脉冲对齐。

## 4. 关键片段 3：Pulse1（通常接 CLK_GATE）

```text
REG 0x0013 REG_PULSE_1_PERIOD
REG 0x0014 REG_PULSE_1_WIDTH
REG 0x0015 REG_PULSE_1_OFFSET
```

解释：

- 你可以通过 Pulse1 调整数据输出窗口与采样节拍关系。
- 在 ad762x_bd.tcl 中，pwm_1 被连到 clk_gate。

## 5. 驱动侧建议

1. 将 period/width/offset 参数化，避免硬编码。
2. 每次修改后统一触发 LOAD_CONFIG。
3. 初期调试先固定 offset=0，再做相位优化。

## 6. 调试重点

1. 示波器确认 cnv 与 clk 输出关系。
2. 改 period 后采样率是否按比例变化。
3. 改 width 后 adc_valid 稳定性是否受影响。
