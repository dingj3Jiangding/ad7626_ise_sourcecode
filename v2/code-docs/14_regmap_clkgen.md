# 14 CLKGEN 寄存器文档解读

源文件：docs/regmap/adi_regmap_clkgen.txt

## 1. 这个文档在驱动中的作用

时钟模块负责给采样链提供稳定工作时钟，驱动必须先保证它锁定，再启动采样。

## 2. 关键片段 1：复位控制

```text
REG 0x0010 REG_RSTN
[1] MMCM_RSTN
[0] RSTN
```

解释：

- 常见流程是写 1 解除复位。
- MMCM_RSTN 用于 DRP 访问或时钟重配置场景。

## 3. 关键片段 2：锁定状态

```text
REG 0x0017 REG_MMCM_STATUS
[0] MMCM_LOCKED
```

解释：

- 驱动中应轮询 MMCM_LOCKED=1 后再启动 ADC/PWM/DMA。
- 未锁定就启动采样，后续问题通常很隐蔽。

## 4. 关键片段 3：DRP 访问

```text
REG 0x001c REG_DRP_CNTRL
REG 0x001d REG_DRP_STATUS
```

解释：

- 用于高级时钟动态配置。
- 如果你只是先打通采样，可以暂时不启用 DRP 流程。

## 5. 驱动初始化建议

1. 解除 CLKGEN 复位。
2. 轮询 MMCM_LOCKED。
3. 锁定后再启动后级模块。

## 6. 调试建议

1. 把 MMCM_LOCKED 打印到日志。
2. 若频繁掉锁，先查参考时钟源与约束。
3. 调整采样参数前后都读一次锁定位。
