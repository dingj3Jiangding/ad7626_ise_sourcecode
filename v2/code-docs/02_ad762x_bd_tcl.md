# 02 ad762x_bd.tcl 详解

源文件：projects/ad762x_fmc/common/ad762x_bd.tcl

## 1. 这个文件的角色

这是 AD7626 采样链路在 BD 层的主装配脚本：

- 定义采样相关顶层端口
- 实例化 ADC/PWM/DMA/CLKGEN
- 连线数据通路
- 分配 AXI-Lite 地址
- 绑定 DMA 中断

## 2. 关键片段 1：端口定义

```tcl
create_bd_port -dir I ref_clk
create_bd_port -dir O sampling_clk
create_bd_port -dir I dco_p
create_bd_port -dir I dco_n
create_bd_port -dir O cnv
create_bd_port -dir I d_p
create_bd_port -dir I d_n
create_bd_port -dir O clk_gate
```

解释：

- 这是 AD7626 数据面最小 I/O 集。
- ref_clk/sampling_clk/cnv/clk_gate 构成“发给 ADC 的时序控制”。
- dco/d_p/d_n 构成“ADC 回采到 FPGA 的数据时钟与数据线”。

## 3. 关键片段 2：核心 IP 实例化

```tcl
ad_ip_instance axi_ad762x axi_ad762x
ad_ip_parameter axi_ad762x CONFIG.ADC_INIT_DELAY 27

ad_ip_instance axi_pwm_gen axi_pwm_gen
ad_ip_parameter axi_pwm_gen CONFIG.N_PWMS 2
ad_ip_parameter axi_pwm_gen CONFIG.PULSE_0_WIDTH 1
ad_ip_parameter axi_pwm_gen CONFIG.PULSE_0_PERIOD 25
ad_ip_parameter axi_pwm_gen CONFIG.PULSE_1_WIDTH 5
ad_ip_parameter axi_pwm_gen CONFIG.PULSE_1_PERIOD 25

ad_ip_instance axi_dmac axi_ad762x_dma
ad_ip_parameter axi_ad762x_dma CONFIG.DMA_TYPE_SRC 2
ad_ip_parameter axi_ad762x_dma CONFIG.DMA_TYPE_DEST 0

ad_ip_instance axi_clkgen reference_clkgen
```

解释：

- axi_ad762x：采样接收核心。
- axi_pwm_gen：产生 cnv 和 clk_gate。
- axi_dmac：将采样流写入内存。
- reference_clkgen：提供采样链工作时钟。

迁移提示：

- Spartan-6 可继续沿用“功能分层”，但具体 IP 可能需要替代实现。
- ADC_INIT_DELAY 与 iodelay 相关参数要在新板重新校准。

## 4. 关键片段 3：数据通路连线

```tcl
ad_connect reference_clkgen/clk_0 axi_ad762x_dma/fifo_wr_clk
ad_connect axi_ad762x/adc_valid  axi_ad762x_dma/fifo_wr_en
ad_connect axi_ad762x/adc_data   axi_ad762x_dma/fifo_wr_din
ad_connect axi_ad762x/adc_dovf   axi_ad762x_dma/fifo_wr_overflow
```

解释：

- 这是最核心的一条链：ADC IP -> DMA FIFO 写口。
- 你迁移时只要保持这组语义关系，内部实现可换。

## 5. 关键片段 4：控制时序连线

```tcl
ad_connect cnv                    axi_pwm_gen/pwm_0
ad_connect clk_gate               axi_pwm_gen/pwm_1
ad_connect reference_clkgen/clk_0 axi_pwm_gen/ext_clk
```

解释：

- pulse0 驱动 cnv。
- pulse1 驱动 clk_gate。
- 两者共用 ext_clk，确保节拍一致。

## 6. 关键片段 5：地址映射与平台耦合

```tcl
ad_cpu_interconnect 0x44A00000 axi_ad762x
ad_cpu_interconnect 0x44A30000 axi_ad762x_dma
ad_cpu_interconnect 0x44A60000 axi_pwm_gen
ad_cpu_interconnect 0x44a80000 reference_clkgen

ad_mem_hp2_interconnect $sys_cpu_clk sys_ps7/S_AXI_HP2
ad_mem_hp2_interconnect $sys_cpu_clk axi_ad762x_dma/m_dest_axi
ad_cpu_interrupt ps-13 mb-12 axi_ad762x_dma/irq
```

解释：

- 这部分体现了 Zynq PS7 强耦合。
- Spartan-6 没有 PS7/S_AXI_HP2，必须重建内存写通路与中断路径。

## 7. 迁移时要复用和替换什么

可复用：

1. 端口语义与主连线结构。
2. 模块职责划分（ADC/PWM/DMA/CLK）。

必须替换：

1. PS7 相关互连。
2. 地址映射背后的总线基础设施。
3. 中断绑定机制。

## 8. 读懂它后的产出

你应该能画出一张 4 模块数据流图：

1. PWM 产生控制节拍。
2. ADC IP 接收串行数据并转并行。
3. DMA 接收数据流并写内存。
4. CPU 通过 AXI-Lite 控制前三者。
