# 06 axi_ad762x_if.v 详解

源文件：library/axi_ad762x/axi_ad762x_if.v

## 1. 这个文件的角色

它是 AD7626 的“物理接口层”：

1. 接收 dco 差分时钟
2. 接收 d_p/d_n 差分数据
3. 在 dco 域做移位组帧
4. 在 clk 域按 clk_gate 节拍输出 adc_valid + adc_data

## 2. 关键片段 1：双时钟域核心逻辑

```verilog
always @(posedge clk) begin
  adc_valid <= 1'b0;
  clk_gate_d <= {clk_gate_d[0], clk_gate};
  if (clk_gate_d[1] == 1'b1 && clk_gate_d[0] == 1'b0) begin
    adc_data  <= adc_data_int;
    adc_valid <= 1'b1;
  end
end

always @(posedge dco) begin
  adc_data_int <= {adc_data_int[16:0], d_p_int_s};
end
```

解释：

- dco 域不断把输入位流移入 adc_data_int。
- clk 域检测 clk_gate 边沿后，把当前样本推出去并打一拍 adc_valid。
- 这是一个简洁的“采样累积 + 节拍对齐输出”结构。

## 3. 关键片段 2：差分数据接收封装

```verilog
ad_data_in #(
  .FPGA_TECHNOLOGY (FPGA_TECHNOLOGY),
  .IDDR_CLK_EDGE ("OPPOSITE_EDGE"),
  .IODELAY_CTRL (IODELAY_CTRL),
  .IODELAY_GROUP (IO_DELAY_GROUP),
  .REFCLK_FREQUENCY (DELAY_REFCLK_FREQUENCY),
  .DDR_SDR_N(0)
) i_rx_da (...)
```

解释：

- 这里把 d_p/d_n 变成内部单端位流 d_p_int_s。
- DDR_SDR_N=0 代表当前作为 SDR 位流路径使用。

## 4. 关键片段 3：DCO 差分输入

```verilog
IBUFGDS i_rx_clk_ibuf (
  .I  (dco_p),
  .IB (dco_n),
  .O  (dco));
```

解释：

- dco 是所有输入移位操作的采样基准。
- dco 品质和相位稳定性直接决定位对齐是否可靠。

## 5. 为什么这是 Spartan-6 迁移关键文件

1. 该文件逻辑本身可复用。
2. 它依赖的 ad_data_in 原语层通常需要改写成 Spartan-6 版本。
3. 只要保证 d_p_int_s 与 dco 的时序关系不变，上层行为可保持一致。

## 6. 迁移建议

1. 先在仿真里复现 adc_data_int 组帧长度与位序。
2. 再替换原语并做时序收敛。
3. 最后对齐 clk_gate 触发条件，确保 adc_valid 周期正确。

## 7. 你需要重点验证的现象

1. adc_valid 是否和 cnv 节拍一致。
2. adc_data 是否存在 bit slip。
3. 改原语后是否出现亚稳或间歇错误。
