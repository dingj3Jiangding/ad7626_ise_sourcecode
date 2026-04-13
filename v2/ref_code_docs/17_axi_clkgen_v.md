# 17 axi_clkgen.v 详解

源文件：library/axi_clkgen/axi_clkgen.v

## 1. 这个文件的角色

这是参考工程中的可编程时钟发生器 IP，负责把上游输入时钟变换成采样链可用的内部工作时钟。

在 AD7626 参考设计里，它对应实例名 `reference_clkgen`，主要给以下对象供时钟：

1. `sampling_clk`
2. `axi_ad762x/ref_clk`
3. `axi_pwm_gen/ext_clk`

## 2. 关键片段 1：顶层端口

```verilog
input                   clk,
input                   clk2,
output                  clk_0,
output                  clk_1,
```

解释：

- `clk` 是主参考输入时钟。
- `clk2` 是可选的第二参考输入时钟。
- `clk_0` / `clk_1` 是 MMCM 变换后的输出时钟。

迁移理解：

- 在当前 AD7626 路径里，最重要的是 `clk` 和 `clk_0`。
- `clk_1` 在本工程中不是采样主链路必需项。

## 3. 关键片段 2：频率参数

```verilog
parameter integer VCO_DIV = 11,
parameter real    VCO_MUL = 49.000,
parameter real    CLK0_DIV = 6.000,
parameter integer CLK1_DIV = 6,
```

解释：

- 这些参数定义 MMCM 的乘除配置。
- `clk_0` 的频率可近似理解为：

```text
Fclk_0 = Fin x VCO_MUL / VCO_DIV / CLK0_DIV
```

- `clk_1` 的频率可近似理解为：

```text
Fclk_1 = Fin x VCO_MUL / VCO_DIV / CLK1_DIV
```

对本工程的直接意义：

- 在 `ad762x_bd.tcl` 中，`reference_clkgen` 被配置为：
  - `VCO_DIV = 1`
  - `VCO_MUL = 10`
  - `CLK0_DIV = 8`
  - `CLK1_DIV = 4`
- 因此：
  - `clk_0 = Fin x 10 / 8 = 1.25 x Fin`
  - `clk_1 = Fin x 10 / 4 = 2.5 x Fin`

## 4. 关键片段 3：AXI-Lite 控制面

```verilog
up_axi i_up_axi (...);

up_clkgen #(
  .ID(ID),
  .FPGA_TECHNOLOGY(FPGA_TECHNOLOGY),
  .FPGA_FAMILY(FPGA_FAMILY)
) i_up_clkgen (...);
```

解释：

- `up_axi` 把 AXI-Lite 访问转换成 ADI 内部 `up_*` 总线。
- `up_clkgen` 负责寄存器控制、MMCM 复位和 DRP 访问组织。

这说明：

1. `axi_clkgen` 不是“死参数”模块。
2. CPU 可以通过寄存器访问它。
3. 工程里的 `ad_cpu_interconnect 0x44a80000 reference_clkgen` 正是给它分配 AXI-Lite 基地址。

## 5. 关键片段 4：MMCM 实例

```verilog
ad_mmcm_drp #(
  .MMCM_CLKIN_PERIOD (CLKIN_PERIOD),
  .MMCM_VCO_DIV (VCO_DIV),
  .MMCM_VCO_MUL (VCO_MUL),
  .MMCM_CLK0_DIV (CLK0_DIV),
  .MMCM_CLK1_DIV (CLK1_DIV)
) i_mmcm_drp (
  .clk (clk),
  .clk2 (clk2),
  .mmcm_clk_0 (clk_0),
  .mmcm_clk_1 (clk_1),
```

解释：

- 真正完成时钟变换的是 `ad_mmcm_drp`。
- `axi_clkgen.v` 更像是一层“AXI 控制 + MMCM 封装”顶层。

迁移理解：

- 如果未来转 Spartan-6，需要重点确认：
  1. `ad_mmcm_drp` 是否仍可直接用
  2. Spartan-6 上对应原语是否应改成 DCM/PLL 路径
  3. DRP/重配置功能是否保留

## 6. 关键片段 5：时钟选择逻辑

```verilog
generate if (CLKSEL_EN == 1) begin
  assign clk_sel_s = up_clk_sel_s;
end else begin
  assign clk_sel_s = 1'b1;
end
endgenerate
```

解释：

- 如果开启 `CLKSEL_EN`，软件可控制选择哪个输入时钟源。
- 如果未开启，则固定使用默认时钟路径。

对当前工程的意义：

- AD7626 参考路径并不依赖复杂时钟切换。
- 迁移初版通常可先忽略多时钟源选择功能。

## 7. BD 脚本里如何推导 `clk_0` 频率

在 `library/axi_clkgen/bd/bd.tcl` 里，有如下频率推导逻辑：

```tcl
set clk [get_bd_pins "$ip/clk"]
set clk_freq [get_property CONFIG.FREQ_HZ $clk]
set clk0_out_freq [expr ($clk_freq + 0.0) * $vco_mul / ($vco_div * $clk0_div)]
set_property CONFIG.FREQ_HZ $clk0_out_freq $clk0_out
```

解释：

- `clk_freq` 是 Vivado BD 中记录在输入 pin 上的时钟频率属性，不是 RTL 里的硬件信号。
- 工具用它推导 `clk_0` / `clk_1` 的输出频率属性。
- 这个过程发生在 BD 元数据层，不直接出现在综合后的逻辑里。

## 8. 在 AD7626 工程中的连接关系

在 `projects/ad762x_fmc/common/ad762x_bd.tcl` 中：

```tcl
ad_ip_instance axi_clkgen reference_clkgen
ad_ip_parameter reference_clkgen CONFIG.VCO_DIV 1
ad_ip_parameter reference_clkgen CONFIG.VCO_MUL 10
ad_ip_parameter reference_clkgen CONFIG.CLK0_DIV 8
ad_ip_parameter reference_clkgen CONFIG.CLK1_DIV 4

ad_connect reference_clkgen/clk   $sys_cpu_clk
ad_connect reference_clkgen/clk_0 sampling_clk
ad_connect reference_clkgen/clk_0 axi_ad762x/ref_clk
ad_connect reference_clkgen/clk_0 axi_pwm_gen/ext_clk
```

解释：

1. `reference_clkgen` 的输入 `clk` 接平台时钟。
2. `clk_0` 是 AD7626 采样链的关键内部工作时钟。
3. `clk_0` 同时喂给采样接口、PWM 和 DMA 写口时钟。

这说明该 IP 在本工程中的作用是：

- 统一给 AD7626 数据路径与控制路径提供同源节拍。

## 9. 迁移到 Spartan-6 时最值得关注的点

1. 先确认是否真的需要保留可编程 MMCM 架构。
2. 如果只是最小 bring-up，可先用固定频率时钟源替代复杂动态配置。
3. 若继续复用该结构，必须检查 `ad_mmcm_drp` 与 Spartan-6 原语兼容性。
4. 驱动侧仍应保留“解除复位 -> 等待锁定 -> 启动后级模块”的顺序。

## 10. 阅读后应掌握

1. `reference_clkgen` 其实是 `axi_clkgen` 的实例名，不是模块名。
2. `clk_0` 是由 MMCM 参数推导出来的主输出时钟。
3. 该 IP 既提供时钟变换，也提供 AXI-Lite 可编程控制面。
4. 在 AD7626 参考工程中，`clk_0` 是 `axi_ad762x` 和 `axi_pwm_gen` 的共同工作节拍来源。
