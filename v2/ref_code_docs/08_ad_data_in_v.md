# 08 ad_data_in.v 详解

源文件：library/xilinx/common/ad_data_in.v

## 1. 这个文件的角色

这是差分输入与可编程延时封装层，功能顺序是：

1. IBUF/IBUFDS 接收输入
2. IDELAY 可调延时
3. IDDR/IDDRE1 双沿采样（或 SDR 直通）

## 2. 关键片段 1：技术分支定义

```verilog
localparam NONE = -1;
localparam SEVEN_SERIES = 1;
localparam ULTRASCALE = 2;
localparam ULTRASCALE_PLUS = 3;
```

解释：

- 这里只有 7 系和 UltraScale 系。
- 没有 Spartan-6 分支，这是迁移时最直接的阻碍。

## 3. 关键片段 2：IODELAY 控制

```verilog
if (IODELAY_CTRL_ENABLED == 0) begin
  assign delay_locked = 1'b1;
end else begin
  IDELAYCTRL i_delay_ctrl (...);
end
```

解释：

- 开启 IODELAY 控制时依赖 IDELAYCTRL 锁定。
- delay_locked 状态会影响上层对链路健康的判断。

## 4. 关键片段 3：输入缓冲与旁路

```verilog
if (SINGLE_ENDED == 1) begin
  IBUF i_rx_data_ibuf (...);
end else begin
  IBUFDS i_rx_data_ibuf (...);
end

if (IODELAY_ENABLE == 0) begin
  assign rx_data_idelay_s = rx_data_ibuf_s;
end
```

解释：

- 支持单端和差分输入。
- 可关闭延时模块直接旁路，便于最小链路调试。

## 5. 关键片段 4：7 系/UltraScale 分支原语

```verilog
if (FPGA_TECHNOLOGY == SEVEN_SERIES && IODELAY_ENABLE == 1) begin
  IDELAYE2 i_rx_data_idelay (...);
end

if ((FPGA_TECHNOLOGY == ULTRASCALE || FPGA_TECHNOLOGY == ULTRASCALE_PLUS)
  && (IODELAY_ENABLE == 1)) begin
  IDELAYE3 i_rx_data_idelay (...);
end
```

解释：

- 原语硬编码到 Xilinx 新架构系列。
- Spartan-6 需要改成对应原语与控制接口。

## 6. 关键片段 5：DDR/SDR 输出模式

```verilog
if (DDR_SDR_N == 1'b1) begin
  // IDDR/IDDRE1
end else begin
  assign rx_data_p = rx_data_idelay_s;
  assign rx_data_n = 1'b0;
end
```

解释：

- 支持 DDR 与 SDR 两种输出行为。
- AD7626 当前链路在 axi_ad762x_if 里设置为 SDR 模式使用。

## 7. Spartan-6 迁移方案建议

1. 先保留模块接口不变，重写内部原语分支。
2. 先实现差分输入 + SDR 旁路，确认采样能跑通。
3. 再加可调延时与寄存器控制，提高采样裕量。

## 8. 验证重点

1. delay_locked 的语义是否保持一致。
2. tap 写入与读回是否一致。
3. 引入延时后采样误码是否下降。
