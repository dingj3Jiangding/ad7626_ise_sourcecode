# AD7626 在 Spartan-6 上的最小迁移与驱动编写指南

## 1. 目标与范围

目标：从当前项目中只提取 AD7626 采样链路的有效代码，分析其工作方式，并给出在 Spartan-6 新板上编写驱动的落地方案。

本指南只覆盖以下链路：

- 采样时钟与触发：reference_clkgen + axi_pwm_gen
- ADC 接口采集：axi_ad762x_if
- 通道格式化与寄存器：axi_ad762x_channel + up_adc_common/up_adc_channel/up_delay_cntrl
- 数据搬运：axi_dmac
- 顶层差分引脚与时序约束

明确排除（不参与 AD7626 采样主链路）：

- HDMI / I2S / SPDIF / IIC MUX 等外设逻辑
- 与 Zed 平台 UI 或演示相关的外围逻辑

## 2. 参与代码清单（最小集合）

1. projects/ad762x_fmc/Readme.md
作用：确认该工程对应 CN0577，包含 AD7626/AD7625/AD7961/AD7960 器件信息。

2. projects/ad762x_fmc/common/ad762x_bd.tcl
作用：定义 BD 端口、实例化 axi_ad762x/axi_pwm_gen/axi_dmac/axi_clkgen，并完成地址映射与中断连接。

3. library/axi_ad762x/axi_ad762x.v
作用：采样核心顶层，串起接口层、通道层、延时控制、通用寄存器、AXI-Lite 总线。

4. library/axi_ad762x/axi_ad762x_if.v
作用：串行数据接收与组帧，基于 dco 采样 d_p/d_n，拼装 adc_data，并在 clk_gate 边沿给出 adc_valid。

5. library/axi_ad762x/axi_ad762x_channel.v
作用：将采样数据格式化成 32-bit DMA 数据，暴露 ADC 通道寄存器。

6. library/xilinx/common/ad_data_in.v
作用：差分输入 + IDELAY + IDDR 封装（当前仅 7-series/UltraScale 分支）。

7. library/xilinx/common/ad_data_clk.v
作用：ref_clk 差分输入缓冲与全局时钟分发。

8. projects/ad762x_fmc/zed/system_top.v
作用：顶层 I/O 与差分发送（clk/cnv）封装，连接 system_wrapper。

9. projects/ad762x_fmc/zed/system_constr.xdc
作用：引脚分配与输入延时、时钟不确定度约束。

10. docs/regmap/adi_regmap_adc.txt
11. docs/regmap/adi_regmap_dmac.txt
12. docs/regmap/adi_regmap_pwm_gen.txt
13. docs/regmap/adi_regmap_clkgen.txt
14. docs/regmap/adi_regmap_iodelay.txt
作用：驱动寄存器定义来源。

## 3. 现有工程工作机制（只看 AD7626 相关）

### 3.1 BD 级互连与基地址

在 ad762x_bd.tcl 中：

- ADC IP：axi_ad762x，设置 ADC_INIT_DELAY=27
- PWM：2 路脉冲，PULSE_0 用于 cnv，PULSE_1 用于 clk_gate
- DMA：axi_ad762x_dma，FIFO 源到内存目标
- CLKGEN：reference_clkgen，输出 sampling_clk 并喂给 ADC/DMA/PWM

当前地址映射（可作为新板参考，不必完全照搬）：

- 0x44A00000 -> axi_ad762x
- 0x44A30000 -> axi_ad762x_dma
- 0x44A60000 -> axi_pwm_gen
- 0x44A80000 -> reference_clkgen

### 3.2 顶层时钟与差分发送

system_top.v 中关键逻辑：

- ref_clk_p/n 进入 ad_data_clk，得到内部 clk_s（送入 system_wrapper/ref_clk）
- sampling_clk_s 作为 ODDR 时钟
- ODDR + OBUFDS 生成差分输出时钟 clk_p/n（被 clk_gate 门控）
- ODDR + OBUFDS 生成差分 cnv_p/n

这说明：

- cnv 与输出采样时钟都来自 FPGA 内部控制节拍
- dco_p/n 与 d_p/d_n 由 ADC 回传给 FPGA 接收链

### 3.3 采样接收与组帧

axi_ad762x_if.v 核心行为：

- ad_data_in 把 d_p/d_n 转成单端位流 d_p_int_s
- always@(posedge dco) 把位流移入 adc_data_int（18-bit shift）
- always@(posedge clk) 在 clk_gate 边沿条件满足时，锁存 adc_data_int 到 adc_data，并拉高 adc_valid 1 个 clk 周期

### 3.4 通道输出格式

axi_ad762x_channel.v 核心行为：

- ad_datafmt 数据宽度配置为 16-bit，输出扩展为 32-bit（供 DMA）
- 当前默认关闭 DC filter 与 IQ correction
- 通道寄存器由 up_adc_channel 提供

结论：

- 本工程对 AD7626 路径最终有效数据宽度是 16-bit
- 虽然接口层 shift 寄存器是 18-bit，但送格式化时使用低 16-bit
- 对 AD7626（16-bit）这是合理的；若你后续切换到 18-bit 器件，需同步检查 channel 层数据位宽配置

### 3.5 搬运路径

ad762x_bd.tcl 中：

- axi_ad762x/adc_valid -> axi_ad762x_dma/fifo_wr_en
- axi_ad762x/adc_data  -> axi_ad762x_dma/fifo_wr_din
- axi_clkgen 输出时钟作为 DMA fifo_wr_clk

即：ADC IP 产出流直接进入 DMAC FIFO 写口，最终写入内存。

## 4. 为什么当前工程不能直接用于 Spartan-6

### 4.1 工程目标只提供 Zed

system_project.tcl 与 zed/Makefile 都显示项目目标是 ad762x_fmc_zed。

### 4.2 关键依赖是 Zynq PS7 + AXI HP

ad762x_bd.tcl 使用了：

- sys_ps7/S_AXI_HP2
- ad_mem_hp2_interconnect
- ad_cpu_interrupt ps-13

这些是 Zynq PS 专属连接，在 Spartan-6 不可用。

### 4.3 ad_data_in 只覆盖 7-series/UltraScale 代码分支

ad_data_in.v 里 FPGA_TECHNOLOGY 仅定义了：

- SEVEN_SERIES = 1
- ULTRASCALE = 2
- ULTRASCALE_PLUS = 3

并实例化 IDELAYE2/IDELAYE3/IDDR/IDDRE1。没有 Spartan-6 分支，不能直接综合到 Spartan-6。

## 5. Spartan-6 迁移策略（推荐）

### 5.1 复用与替换边界

可直接复用：

- library/axi_ad762x/axi_ad762x.v
- library/axi_ad762x/axi_ad762x_if.v 的状态机与组帧思路
- library/axi_ad762x/axi_ad762x_channel.v
- regmap 文档定义的寄存器访问流程

必须替换：

- board 工程脚本（Zed -> 你的 Spartan-6 板）
- 采样输入原语封装（ad_data_in 的器件原语层）
- 内存搬运路径（PS7 HP2 + axi_dmac 依赖项）
- 引脚与时序约束文件（XDC/UCF 按工具链）

### 5.2 原语映射建议

当前工程原语 -> Spartan-6 参考

- ODDR -> ODDR2
- IDDR/IDDRE1 -> IDDR2
- IDELAYE2/IDELAYE3 -> IODELAY2 或等效结构
- IBUFGDS / OBUFDS 多数可保留同名或替代等效原语（按器件库确认）

### 5.3 系统结构建议

如果你有软核 CPU（MicroBlaze 或其他）：

- 保留 AXI-Lite 控制面，复用 ADC/PWM/CLKGEN 的寄存器模型
- 将 DMAC 目标改为你板上可用的 DDR 控制器接口

如果你是纯硬件流式方案（无 CPU）：

- 去掉 up_axi/up_adc_common 软件控制依赖
- 固化关键参数（延时 tap、脉冲周期）
- 采样数据直接送 FIFO/BRAM/自定义搬运模块

## 6. 新板驱动编写步骤（建议顺序）

### 步骤 1：先打通采样硬件最小闭环

最小端口：

- 输入：ref_clk_p/n, dco_p/n, d_p/n
- 输出：cnv_p/n, clk_p/n

先观察：

- cnv 与 clk 输出是否符合预期频率
- dco 是否稳定进入 FPGA
- adc_valid 是否周期性脉冲

### 步骤 2：实现寄存器初始化驱动

优先控制寄存器（来自 regmap 文档）：

- ADC：REG_RSTN (0x0010), REG_CNTRL (0x0011), REG_STATUS (0x0017)
- PWM：REG_RSTN, REG_PULSE_0_PERIOD/WIDTH, REG_PULSE_1_PERIOD/WIDTH
- CLKGEN：REG_RSTN, REG_MMCM_STATUS
- DMAC：CONTROL(0x100), DEST_ADDRESS(0x104), X_LENGTH(0x106), TRANSFER_SUBMIT(0x102), TRANSFER_DONE(0x10a)

地址单位注意：

- up_axi 会把 AXI 地址右移 2 位后送入内部寄存器译码（即按 32-bit 字寻址）
- 因此 regmap 中的寄存器号通常对应 word offset
- 若你的驱动按 byte 地址访问 AXI-Lite，请使用 byte_offset = reg_offset << 2

### 步骤 3：按以下顺序上电与启动

示例伪代码（寄存器名对照本仓库 regmap）：

1. 复位所有模块（ADC/PWM/CLKGEN/DMAC）
2. 打开 CLKGEN，等待 MMCM_LOCKED=1
3. 配置 PWM：
   - pulse0 -> cnv
   - pulse1 -> clk_gate
   - 写 LOAD_CONFIG
4. ADC 解除复位，等待 REG_STATUS.STATUS=1
5. （可选）执行 iodelay 扫描，确定稳定 tap
6. 配置 DMA：
   - ENABLE=1
   - DEST_ADDRESS=buffer
   - X_LENGTH=bytes-1
   - TRANSFER_SUBMIT=1
7. 轮询 TRANSFER_DONE 或中断完成

### 步骤 4：采样率参数化

在本工程中，cnv 由 PWM 周期决定。可按下式估算：

- Fs ~= Fext_clk / PULSE_0_PERIOD
- Tcnv_high = PULSE_0_WIDTH / Fext_clk

因此新板驱动必须把 PULSE_PERIOD/PULSE_WIDTH 作为可配置参数。

## 7. 只提取代码时的目录建议

建议你在新板工程先复制以下文件作为初版：

- library/axi_ad762x/axi_ad762x.v
- library/axi_ad762x/axi_ad762x_if.v
- library/axi_ad762x/axi_ad762x_channel.v
- library/xilinx/common/ad_data_clk.v
- （重写）library/xilinx/common/ad_data_in.v 的 Spartan-6 版本
- 参考 projects/ad762x_fmc/common/ad762x_bd.tcl 重建你的 top 连接

其余如 HDMI/I2S/SPDIF 相关文件不要带入。

## 8. 风险点与排障优先级

1. 首要风险：Spartan-6 输入延时/双沿采样原语替换不当，导致位对齐失败。
2. 次要风险：cnv 与 clk_gate 相位关系错误，导致 adc_valid 时刻对应错误样本。
3. 次要风险：DMA 目标接口带宽不足，出现溢出或丢样。

建议调试顺序：

1. 先看 cnv/clk/dco 三时钟关系。
2. 再看 adc_valid 与 adc_data 的更新节拍。
3. 最后压测 DMA/存储链路。

## 9. 结论

这个项目里与你目标最相关的核心已经完整可提取，但它是面向 Zed/Zynq 的。迁移到 Spartan-6 的关键不是 ADC 算法本身，而是三件事：

- I/O 原语层替换
- PS7/AXI HP 相关搬运路径重构
- 新板时钟与约束重建

只要先把这三点拆开处理，你就能在最小改动下复用 ADI 的 ad762x 采样主链路。