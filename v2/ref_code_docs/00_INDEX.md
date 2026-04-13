# AD7626 Spartan-6 迁移代码阅读索引

本目录是按“必看清单”逐文件拆解的详解文档，目标是帮助你在迁移前快速建立完整心智模型。

## 阅读顺序建议

1. 01_project_readme.md
2. 02_ad762x_bd_tcl.md
3. 03_system_top_v.md
4. 04_system_constr_xdc.md
5. 05_axi_ad762x_v.md
6. 06_axi_ad762x_if_v.md
7. 07_axi_ad762x_channel_v.md
8. 08_ad_data_in_v.md
9. 09_ad_data_clk_v.md
10. 10_up_axi_v.md
11. 11_regmap_adc.md
12. 12_regmap_dmac.md
13. 13_regmap_pwm_gen.md
14. 14_regmap_clkgen.md
15. 15_regmap_iodelay.md
16. 16_driver_guide_usage.md
17. 17_axi_clkgen_v.md

## 与总纲文档关系

- 总纲文档：projects/ad762x_fmc/common/ad7626_spartan6_driver_guide.md
- 本目录文档：偏“逐文件代码讲解”，每份都带关键片段 + 解释 + 迁移提示。

## 输出目标

看完本目录后，你应该能回答三个问题：

1. AD7626 采样数据在代码中是如何从引脚进入 DMA 的。
2. 哪些模块可以直接复用，哪些必须因 Spartan-6 重写。
3. 新板驱动初始化顺序与关键寄存器如何组织。
