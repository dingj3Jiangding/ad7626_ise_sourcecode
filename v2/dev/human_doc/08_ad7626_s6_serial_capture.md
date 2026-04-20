# ad7626_s6_serial_capture 结合代码说明

对应源码：`v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`

## 1. 这个模块现在负责什么

这个模块当前做三件事：

1. 用 `DCO±` 在 IO 边界采样 `D±`
2. 在 DCO 域内组出 16bit `sample_word_dco`
3. 在 `sys_clk` 域内用 toggle 方式输出 `sample_valid/sample_data`

和前一版相比，当前实现多了一条控制链：

`read_start_align -> capture_req_sys -> DCO 域消费 -> ack 返回`

它的目的不是传数据，而是让 DCO 域的组字起点尽量和 `read_start` 对齐。

## 2. 顶层接口的关键变化

现在除了原来的：

1. `sys_clk`
2. `dco_p/n`
3. `d_p/n`
4. `sample_valid/sample_data`

还多了：

```verilog
input wire read_start_align
```

这个信号来自 `timing_gen`，表示当前 sample 的 read burst 开始了。

当前设计里，它不会直接跨到 DCO 域打一拍 pulse，而是先在 `sys_clk` 域变成 level request。

另外，当前代码还加了一个实验参数：

```verilog
parameter integer FULL_CYCLE_CAPTURE = 1
```

含义是：

1. `0`：切回旧的 `half-cycle` 行为
2. `1`：默认采用实验性的 `full-cycle` 组字行为

## 3. IO 边界采样还是怎么做的

关键片段：

```verilog
IBUFGDS i_dco_ibufds (...);
IBUFDS  i_data_ibufds (...);

IDDR2 i_data_iddr2 (
  .Q0(data_rise_s),
  .C0(dco_clk_s),
  .C1(~dco_clk_s),
  .D (data_s)
);
```

解释：

1. `DCO±` 先变成单端 `dco_clk_s`
2. `D±` 先变成单端 `data_s`
3. `IDDR2.Q0` 在 `dco_clk_s` 上升沿采到 `data_rise_s`

当前实际真正使用的是：

`Q0 -> data_rise_s`

## 4. DCO 域现在怎么开始收一个新字

当前 DCO 域新增了这几个状态：

1. `capture_req_sys`
2. `capture_req_seen_dco`
3. `capture_active_dco`
4. `capture_ack_toggle_dco`

含义：

1. `capture_req_sys`
   `sys_clk` 域发出的“开始收新字”请求
2. `capture_req_seen_dco`
   DCO 域已经消费过这一次 request
3. `capture_active_dco`
   DCO 域正在收当前 16bit
4. `capture_ack_toggle_dco`
   DCO 域确认已消费 request，并把这个确认送回 `sys_clk`

关键片段：

```verilog
if (!capture_active_dco) begin
  if (!capture_req_seen_dco && capture_req_sys) begin
    shift_reg_dco        <= {{(SAMPLE_WIDTH-1){1'b0}}, data_rise_s};
    bit_count_dco        <= {{(BIT_COUNT_WIDTH-1){1'b0}}, 1'b1};
    capture_req_seen_dco <= 1'b1;
    capture_active_dco   <= 1'b1;
    capture_ack_toggle_dco <= ~capture_ack_toggle_dco;
  end
end
```

解释：

1. 如果当前不在接收状态
2. 且 DCO 域看到一个新的 request
3. 那就从这一拍开始接收一个新字
4. 同时回一个 ack toggle 给 `sys_clk`

## 5. DCO 域怎么继续组字

关键片段：

```verilog
shift_reg_dco <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};

if (bit_count_dco == (SAMPLE_WIDTH - 1)) begin
  sample_word_dco    <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};
  sample_toggle_dco  <= ~sample_toggle_dco;
  bit_count_dco      <= 0;
  capture_active_dco <= 1'b0;
end
```

解释：

1. 每次 DCO 域接收一个 bit，就继续 shift
2. 收满 16bit 后锁存成 `sample_word_dco`
3. 然后翻转 `sample_toggle_dco`
4. 告诉 `sys_clk` 域：一个完整样本已经好了

## 5.1 当前代码里的两种组字模式

现在 `serial_capture` 不是只有一种 DCO 组字方式，而是有两个 generate 分支：

1. `gen_half_cycle_capture`
2. `gen_full_cycle_capture`

### half-cycle 模式

关键形式：

```verilog
always @(negedge dco_clk_s or negedge rstn)
```

特点：

1. `IDDR2.Q0(data_rise_s)` 在 `posedge dco_clk_s` 更新
2. `shift_reg_dco/sample_word_dco` 在同周期 `negedge dco_clk_s` 接收
3. 因此形成 `rise -> fall` 的 `2 ns` 半周期路径

这个模式和当前顶层连法兼容，但它就是 timing 报告里 fail 的主因。

### full-cycle 模式

关键形式：

```verilog
always @(posedge dco_clk_s or negedge rstn)
```

并新增一个过渡状态：

```verilog
reg capture_arm_dco;
```

它的作用是：

1. 第一个 DCO 上升沿先让 `IDDR2.Q0` 把 bit 采出来
2. 下一次 DCO 上升沿再把上一次采到的 `data_rise_s` 推进到 `shift_reg_dco`
3. 从而把 `data_rise_s -> shift_reg_dco` 变成整周期路径

这个分支是为了验证时序架构是否能从半周期切到整周期。

## 6. `sys_clk -> DCO` 这条 request/ack 是怎么工作的

关键片段：

```verilog
capture_ack_sync <= {capture_ack_sync[1:0], capture_ack_toggle_dco};

if (read_start_align) begin
  capture_req_sys <= 1'b1;
end else if (capture_ack_seen_sys) begin
  capture_req_sys <= 1'b0;
end
```

解释：

1. `read_start_align` 到来时，`sys_clk` 域把 `capture_req_sys` 拉高
2. 这个 request 会保持为高
3. 直到 DCO 域真正消费它，并翻转 `capture_ack_toggle_dco`
4. `sys_clk` 域检测到 ack 后，再把 `capture_req_sys` 清掉

一句话总结：

这不是 pulse 跨域，而是 level request 加 ack 清除。

## 7. `DCO -> sys_clk` 这条样本输出链怎么工作

这部分还保持原来的 toggle 思路：

```verilog
sample_toggle_sync <= {sample_toggle_sync[2:0], sample_toggle_dco};
sample_word_meta   <= sample_word_dco;
sample_word_sync   <= sample_word_meta;
```

以及：

```verilog
if (sample_toggle_sync[3] ^ sample_toggle_sync[2]) begin
  sample_valid <= 1'b1;
  sample_data  <= sample_word_sync;
end
```

解释：

1. DCO 域每完成一个字，就翻转一次 `sample_toggle_dco`
2. `sys_clk` 域对这个 toggle 做同步
3. 检测到翻转时，打一拍 `sample_valid`
4. 并输出 `sample_data`

## 8. 当前为了调试暴露了哪些内部信号

目前已经加了这些 debug 输出：

1. `sample_word_dco_dbg`
2. `data_rise_dbg`
3. `bit_count_dco_dbg`
4. `shift_reg_dco_dbg`
5. `capture_req_sys_dbg`
6. `capture_active_dco_dbg`
7. `capture_ack_toggle_dco_dbg`

这几组信号主要用于排查两个问题：

1. `read_start` 和 `bit_count_dco` 的对齐关系
2. request/ack 链到底有没有真正启动 DCO 域接收

## 9. 当前代码的已知问题

虽然功能上已经加入了 `read_start` 对齐机制，但 static timing 说明当前 DCO 域仍有一个结构性问题：

1. `IDDR2.Q0(data_rise_s)` 在 `posedge dco_clk_s` 产生
2. `shift_reg_dco/sample_word_dco` 在 `negedge dco_clk_s` 接收
3. 所以形成了 `2 ns` 的 `rise -> fall` 半周期路径

这就是当前 timing fail 的主因。

更详细分析见：

`v2/dev/human_doc/12_day1_2_static_timing_report.md`

## 10. full-cycle 实验模式的限制

`FULL_CYCLE_CAPTURE=1` 不是没有代价的直接修复，当前版本有一个明确限制：

1. 最后 1bit 不是在采样它的那个上升沿立刻进入 fabric
2. 它要等“下一次 DCO 上升沿”才会从 `data_rise_s` 推进到 `shift_reg_dco/sample_word_dco`

所以在当前 16bit burst 组织方式下：

1. 前 16 个 DCO 上升沿负责把 `bit[15:0]` 送进 `IDDR2.Q0`
2. 还需要第 17 个 DCO 上升沿，把最后 1bit flush 进 fabric

这说明这个模式当前验证的是“整周期消费 `Q0`”这个想法本身，不代表它已经可以原样替换现有顶层 burst。

## 11. 用于验证的 simulation TB

当前已经新增模块级 testbench：

`v2/dev/tb/Day1-2/tb_ad7626_s6_serial_capture.v`

这个 TB 的目的很明确：

1. 例化 `FULL_CYCLE_CAPTURE=1` 的 DUT
2. 发送多组 16bit 测试字
3. 在 full-cycle 模式下额外补 1 个 flush edge
4. 同时检查 DCO 域 `sample_word_dco` 和 sys 域 `sample_data`

TB 文件里还做了两件事，方便独立仿真：

1. 默认提供 `IBUFDS/IBUFGDS/IDDR2` 的简单 stub
2. 如果你用 ISE/UNISIM，可以定义 `USE_XILINX_UNISIM` 切回真实库模型

## 12. 当前阶段怎么理解这个模块

现在这份 `serial_capture` 文档不要再把它理解成“已经定型的最终版本”，而应该理解成：

1. 功能上已经开始尝试用 `read_start_align` 修复 sample 边界
2. CDC 上已经从 pulse 改成了 level request/ack
3. 代码里已经加入了 `FULL_CYCLE_CAPTURE` 实验分支
4. 但这个实验分支当前仍需要额外 flush edge，所以还不是顶层硬件的最终解
