# 09 ad_data_clk.v 详解

源文件：library/xilinx/common/ad_data_clk.v

## 1. 这个文件的角色

这是一个非常薄的时钟接入封装：

1. 选择单端或差分输入
2. 做全局时钟缓冲
3. 输出内部时钟给后级逻辑

## 2. 关键片段 1：输入缓冲选择

```verilog
if (SINGLE_ENDED == 1) begin
  IBUFG i_rx_clk_ibuf (...);
end else begin
  IBUFGDS i_rx_clk_ibuf (...);
end
```

解释：

- SINGLE_ENDED=0 时走差分 IBUFGDS。
- AD7626 参考设计中 ref_clk_p/n 是差分输入。

## 3. 关键片段 2：全局时钟分发

```verilog
BUFG i_clk_gbuf (
  .I (clk_ibuf_s),
  .O (clk));
```

解释：

- 不做复杂时钟管理，只负责进入全局树。
- 这是保证后续逻辑时序一致性的基础。

## 4. 关键片段 3：locked 恒定为 1

```verilog
assign locked = 1'b1;
```

解释：

- 该模块本身不含 PLL/MMCM，不产生真实 lock 过程。
- 若迁移后你接入 DCM/PLL，应把 locked 替换为真实状态。

## 5. 迁移建议

1. 先保持输入缓冲 + 全局缓冲结构不变。
2. 确认 Spartan-6 对应缓冲原语与布线资源。
3. 如果改成经 DCM/PLL，记得同步改上层复位逻辑。

## 6. 快速检查点

1. ref_clk 进入后是否稳定。
2. clk 是否被工具识别为全局时钟。
3. 时钟域 crossing 是否因替换而变化。
