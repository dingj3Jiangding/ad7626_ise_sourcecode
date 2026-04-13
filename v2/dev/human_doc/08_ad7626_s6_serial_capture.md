# ad7626_s6_serial_capture 结合代码说明

对应源码：`v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`

## 1. 这个模块的职责

这个模块负责把 ADC 回来的：

1. `DCO±`
2. `D±`

变成系统侧可用的：

1. `sample_valid`
2. `sample_data[15:0]`

它的实现分成两段：

1. DCO 域 source-synchronous 接收
2. 回到 `sys_clk` 域的轻量跨域输出

## 2. 差分输入和边界采样

关键片段：

```verilog
IBUFGDS i_dco_ibufds (...);
IBUFDS  i_data_ibufds (...);

IDDR2 i_data_iddr2 (
  .Q0 (data_rise_s),
  .Q1 (data_fall_s),
  .C0 (dco_clk_s),
  .C1 (~dco_clk_s),
  .D  (data_s)
);
```

解释：

1. `DCO±` 先进差分时钟输入缓冲。
2. `D±` 先进差分数据输入缓冲。
3. `IDDR2` 用 `DCO` 在 IO 边界采样 `D`。
4. 我们真正使用的是 `Q0`，也就是 `DCO` 上升沿采到的值。

这正对应 AD7626 的规则：

1. `D` 在 `DCO` 下降沿更新。
2. 主机在 `DCO` 上升沿采样。

## 3. 为什么后面的移位在 `negedge dco_clk_s`

关键片段：

```verilog
always @(negedge dco_clk_s or negedge rstn) begin
  shift_reg_dco <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};
end
```

原因是：

1. `data_rise_s` 是前一个 `DCO` 上升沿刚刚打进来的位。
2. 到后半个时钟，也就是 `negedge dco_clk_s` 时，它已经稳定。
3. 这时再把它移进移位寄存器，时序关系更清楚。

## 4. 16bit 组帧

关键片段：

```verilog
if (bit_count_dco == (SAMPLE_WIDTH - 1)) begin
  sample_word_dco   <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};
  sample_toggle_dco <= ~sample_toggle_dco;
  bit_count_dco     <= 0;
end
```

解释：

1. 每收到 1 个 `DCO` 有效位，就把 1bit 推入移位寄存器。
2. 收满 16bit 后，锁存成 `sample_word_dco`。
3. 然后翻转一次 `sample_toggle_dco`，告诉系统域“新样本到了”。

## 5. 为什么跨域不用 FIFO

当前跨域做法是：

1. DCO 域保留完整字
2. 用 toggle 告诉系统域来了一个新字
3. 系统域对 toggle 做同步
4. 再把样本总线打一拍取走

这不是最终最强壮的通用 CDC 方案，但对当前 Day1-2 足够：

1. 每个样本之间间隔远大于几个 `sys_clk`
2. 我们先追求 bring-up 简洁可验证
3. 后续如果板上需要更强鲁棒性，再升级成 FIFO

## 6. 为什么要丢第一帧

代码里有：

```verilog
parameter integer DROP_FIRST_SAMPLE = 1
```

这是因为 AD7626 上电后第一帧转换结果无效。  
所以默认把第一帧先丢掉，更符合 datasheet 行为。
