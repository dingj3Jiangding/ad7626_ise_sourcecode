# 07 axi_ad762x_channel.v 详解

源文件：library/axi_ad762x/axi_ad762x_channel.v

## 1. 这个文件的角色

这是“数据格式与通道控制层”：

1. 把接口层数据转成 DMA 输出格式
2. 提供通道级寄存器控制
3. 暴露状态位到软件

## 2. 关键片段 1：数据格式化

```verilog
ad_datafmt #(
  .DATA_WIDTH (16),
  .BITS_PER_SAMPLE (32),
  .DISABLE (DATAFORMAT_DISABLE)
) i_ad_datafmt (
  .valid (adc_valid_in),
  .data (adc_data_in[15:0]),
  .valid_out (adc_valid),
  .data_out (adc_data)
);
```

解释：

- 输入只取 adc_data_in[15:0]，对应 AD7626 的 16-bit 数据。
- 输出扩展到 32-bit，方便 DMA/内存对齐。

## 3. 关键片段 2：通道控制寄存器

```verilog
up_adc_channel #(
  .CHANNEL_ID (0),
  .USERPORTS_DISABLE (USERPORTS_DISABLE),
  .DATAFORMAT_DISABLE (DATAFORMAT_DISABLE),
  .DCFILTER_DISABLE (1'b1),
  .IQCORRECTION_DISABLE (1'b1)
) i_up_adc_channel (...)
```

解释：

- 当前通道 ID=0，单通道模式。
- DC filter 与 IQ correction 都关闭，链路保持最小化。

## 4. 关键片段 3：固定用户数据类型

```verilog
.adc_usr_datatype_signed (1'b1),
.adc_usr_datatype_total_bits (8'd16),
.adc_usr_datatype_bits (8'd16)
```

解释：

- 这里已经把数据类型约束为 16-bit signed。
- 若你未来切 AD7960 18-bit，需要同步调整这里与上游位宽路径。

## 5. 迁移关注点

1. 先保持 DATA_WIDTH/BITS_PER_SAMPLE 不变，优先打通链路。
2. 若只做裸采样，可以暂时不启用复杂数据格式选项。
3. 软件读到的通道状态来自该层寄存器，不要绕开它。

## 6. 调试时最有用的观察点

1. adc_valid_in 与 adc_valid 是否一一对应。
2. adc_data[31:16] 的填充方式是否符合预期。
3. 通道寄存器写入后，输出格式是否按预期变化。
