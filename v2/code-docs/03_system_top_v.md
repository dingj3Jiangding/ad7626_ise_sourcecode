# 03 system_top.v 详解

源文件：projects/ad762x_fmc/zed/system_top.v

## 1. 这个文件的角色

这是板级顶层封装，负责把 BD 内部逻辑映射到真实引脚。

对 AD7626 迁移最关键的功能只有三类：

1. 参考时钟接入
2. cnv/clk 差分输出生成
3. dco/data 输入回传到 system_wrapper

## 2. 关键片段 1：AD7626 相关引脚

```verilog
input  ref_clk_p,
input  ref_clk_n,
output clk_p,
output clk_n,
input  dco_p,
input  dco_n,
input  d_n,
input  d_p,
output cnv_p,
output cnv_n
```

解释：

- ref_clk_p/n 是外部参考时钟输入。
- clk_p/n 和 cnv_p/n 是发往 ADC 的差分控制信号。
- dco_p/n 与 d_p/d_n 是 ADC 回传输入。

## 3. 关键片段 2：参考时钟接入

```verilog
ad_data_clk #(
  .SINGLE_ENDED (0)
) i_ref_clk (
  .clk_in_p (ref_clk_p),
  .clk_in_n (ref_clk_n),
  .clk (clk_s));
```

解释：

- 通过 ad_data_clk 把差分参考时钟变成内部全局时钟 clk_s。
- clk_s 再送到 system_wrapper/ref_clk。

## 4. 关键片段 3：输出采样时钟与 CNV 生成

```verilog
ODDR i_tx_clk_oddr (
  .C  (sampling_clk_s),
  .D1 (clk_gate),
  .D2 (1'b0),
  .Q  (gated_sampling_clk));

ODDR i_cnv_oddr (
  .C  (sampling_clk_s),
  .D1 (cnv),
  .D2 (cnv),
  .Q  (cnv_s));

OBUFDS i_tx_data_obuf (
  .I (gated_sampling_clk),
  .O (clk_p),
  .OB (clk_n));

OBUFDS OBUFDS_cnv (
  .I (cnv_s),
  .O (cnv_p),
  .OB (cnv_n));
```

解释：

- sampling_clk_s 是内部节拍基准。
- clk_gate 决定输出差分时钟是否有效。
- cnv 通过 ODDR 同步发送到差分输出。

Spartan-6 迁移提示：

- ODDR 通常替换为 ODDR2。
- OBUFDS 需按器件库确认是否同名可用。

## 5. 关键片段 4：与 system_wrapper 的关键连接

```verilog
.ref_clk      (clk_s),
.sampling_clk (sampling_clk_s),
.dco_p        (dco_p),
.dco_n        (dco_n),
.d_n          (d_n),
.d_p          (d_p),
.cnv          (cnv),
.clk_gate     (clk_gate)
```

解释：

- 这是顶层和 BD 的“采样接口契约”。
- 你新板 top 只要保持这个语义连接，内部平台模块可以替换。

## 6. 对迁移最有价值的阅读点

1. AD7626 相关信号在顶层的方向和极性。
2. ODDR 对输出时序的作用。
3. system_wrapper 需要哪些最小端口即可打通采样。

## 7. 建议保留与删减

建议保留：

1. ref_clk/cnv/clk/dco/data 相关信号链。
2. 与采样有关的 ODDR/OBUFDS 构造。

建议删减：

1. HDMI/I2S/SPDIF/IIC mux/GPIO 等无关外设。
2. 仅为 Zed 平台服务的外围管脚封装。
