# 11 ADC 寄存器文档解读

源文件：docs/regmap/adi_regmap_adc.txt

## 1. 这个文档在驱动中的作用

它定义了 ADC 公共控制寄存器，是你驱动初始化和状态判断的依据。

## 2. 关键片段 1：复位寄存器

```text
REG 0x0010 REG_RSTN
[2] CE_N
[1] MMCM_RSTN
[0] RSTN
```

解释：

- 上电后常见流程是先解除 RSTN，再根据需要处理 MMCM_RSTN。
- CE_N 用于时钟使能控制。

## 3. 关键片段 2：接口控制寄存器

```text
REG 0x0011 REG_CNTRL
[16] SDR_DDR_N
[1]  DDR_EDGESEL
[0]  PIN_MODE
```

解释：

- SDR_DDR_N 决定接口类型。
- DDR_EDGESEL 决定样本拆分边沿语义。
- PIN_MODE 决定时钟复用/引脚复用模式。

## 4. 关键片段 3：状态寄存器

```text
REG 0x0017 REG_STATUS
[3] PN_ERR
[2] PN_OOS
[1] OVER_RANGE
[0] STATUS
```

解释：

- STATUS=1 通常代表接口就绪。
- PN_ERR/PN_OOS/OVER_RANGE 用于运行态健康监控。

## 5. 关键片段 4：时钟测量寄存器

```text
REG 0x0015 REG_CLK_FREQ
REG 0x0016 REG_CLK_RATIO
```

解释：

- 可用于驱动里做时钟一致性自检。
- 当采样行为异常时，这是优先排查项之一。

## 6. 驱动初始化建议

1. 写 REG_RSTN 解除复位。
2. 设 REG_CNTRL 到目标接口模式。
3. 轮询 REG_STATUS.STATUS 直到就绪。
4. 采样过程中周期性读取 STATUS 做健康监控。

## 7. 常见误区

1. 只写复位不读状态。
2. 没确认 SDR/DDR 配置就开始搬运数据。
3. 出现异常时忽略 PN/OVER_RANGE 状态位。
