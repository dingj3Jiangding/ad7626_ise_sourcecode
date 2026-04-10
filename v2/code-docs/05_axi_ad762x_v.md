# 05 axi_ad762x.v 详解

源文件：library/axi_ad762x/axi_ad762x.v

## 1. 这个文件的角色

这是 AD7626 采样核心顶层，负责把四类子模块串起来：

1. 接口层 axi_ad762x_if
2. 通道层 axi_ad762x_channel
3. 延时控制 up_delay_cntrl
4. 控制总线 up_axi + up_adc_common

## 2. 关键片段 1：顶层参数与端口

```verilog
parameter IODELAY_CTRL = 1,
parameter DELAY_REFCLK_FREQUENCY = 200,
parameter ADC_INIT_DELAY = 0

input  delay_clk,
input  ref_clk,
input  clk_gate,
input  dco_p,
input  dco_n,
input  d_p,
input  d_n,

output adc_valid,
output [31:0] adc_data,
input  adc_dovf
```

解释：

- delay_clk 是 IODELAY 参考时钟。
- ref_clk 是接口控制时钟域。
- adc_valid/adc_data 是给 DMA 的标准流接口。

## 3. 关键片段 2：接口层实例

```verilog
axi_ad762x_if #(
  .FPGA_TECHNOLOGY (FPGA_TECHNOLOGY),
  .IO_DELAY_GROUP (IO_DELAY_GROUP),
  .DELAY_REFCLK_FREQUENCY (DELAY_REFCLK_FREQUENCY),
  .IODELAY_CTRL (IODELAY_CTRL)
) axi_ad762x_if_inst (...)
```

解释：

- 这里是“引脚信号 -> 采样字”的入口。
- 迁移到 Spartan-6 时，最大的兼容风险在这个模块依赖的 ad_data_in 原语层。

## 4. 关键片段 3：通道层实例

```verilog
axi_ad762x_channel #(
  .USERPORTS_DISABLE (USERPORTS_DISABLE),
  .DATAFORMAT_DISABLE (DATAFORMAT_DISABLE)
) i_channel (
  .adc_data_in (adc_data_ch_s),
  .adc_valid_in (adc_valid_ch_s),
  .adc_valid (adc_valid),
  .adc_data (adc_data)
);
```

解释：

- 把接口层输出转成 DMA 友好的 32-bit 数据格式。
- 你驱动中看到的数据格式，最终由这里决定。

## 5. 关键片段 4：延时控制

```verilog
up_delay_cntrl #(
  .INIT_DELAY (ADC_INIT_DELAY),
  .DATA_WIDTH (2),
  .BASE_ADDRESS (6'h02)
) i_delay_cntrl (...)
```

解释：

- INIT_DELAY 对应上电初值，常见用于先给一个保守 tap。
- BASE_ADDRESS 说明 delay 控制寄存器被映射在统一 regmap 空间中。

## 6. 关键片段 5：AXI-Lite 控制入口

```verilog
up_axi i_up_axi (
  .up_axi_awaddr (s_axi_awaddr),
  .up_axi_wdata  (s_axi_wdata),
  .up_axi_araddr (s_axi_araddr),
  .up_axi_rdata  (s_axi_rdata),
  .up_wreq (up_wreq_s),
  .up_rreq (up_rreq_s)
);
```

解释：

- 这是软件读写寄存器的唯一入口。
- 迁移时即使不用 AXI，也要保留等价控制通路，否则 regmap 驱动逻辑无法复用。

## 7. 迁移时重点

1. 保留模块分层，不要把逻辑全部拍扁。
2. 先保持 adc_valid/adc_data 语义稳定，再替换底层原语。
3. 若新平台无 AXI-Lite，可实现一层轻量寄存器桥，保持软件接口不变。

## 8. 阅读后应掌握

1. 采样核心顶层如何拼接。
2. 控制面与数据面在哪里汇合。
3. 哪些参数决定延时与格式行为。
