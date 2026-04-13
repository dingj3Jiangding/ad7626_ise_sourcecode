# ad7626_min_loopback_top 结合代码说明

对应源码：`v2/dev/rtl/Day1-1/ad7626_min_loopback_top.v`

这个模块是 Day1 上午最小闭环顶层，目标是把“发位流”和“收位流”放在同一个模块里自检。

## 1) 先看模块连线骨架（原码）

```verilog
wire frame_start_s;
wire bit_tick_s;
wire frame_busy_s;

wire sample_valid_s;
wire [SAMPLE_WIDTH-1:0] sample_data_s;
wire [COUNTER_WIDTH-1:0] sample_count_s;
wire align_error_s;

reg  [SAMPLE_WIDTH-1:0] tx_word;
reg  [SAMPLE_WIDTH-1:0] tx_shift;

wire serial_bit_s;
```

解释：

- `frame_start_s/bit_tick_s` 是时序发生器输出。
- `tx_word/tx_shift/serial_bit_s` 组成内部串行测试源。
- `sample_*_s` 和 `align_error_s` 是接收核输出。

## 2) 调试信号映射（原码）

```verilog
assign serial_bit_s    = tx_shift[SAMPLE_WIDTH-1];
assign serial_data_dbg = serial_bit_s;

assign sample_valid    = sample_valid_s;
assign sample_data     = sample_data_s;
assign sample_count    = sample_count_s;
assign align_error     = align_error_s;
assign frame_start_dbg = frame_start_s;
assign bit_tick_dbg    = bit_tick_s;
```

解释：

- 串行发送采用 `MSB-first`，因此每次都取 `tx_shift` 的最高位。
- `_dbg` 信号全部直接导出，便于你后面挂 ILA 或 testbench 看节拍关系。

## 3) 时序发生器实例（原码）

```verilog
ad7626_min_timing_gen #(
  .CNV_PERIOD(CNV_PERIOD),
  .ACQ_DELAY(ACQ_DELAY),
  .SAMPLE_WIDTH(SAMPLE_WIDTH),
  .SCLK_DIV(SCLK_DIV)
) u_timing_gen (
  .clk(clk),
  .rstn(rstn),
  .frame_start(frame_start_s),
  .bit_tick(bit_tick_s),
  .frame_busy(frame_busy_s)
);
```

解释：

- 顶层不自己生成脉冲，统一交给 `ad7626_min_timing_gen`。
- 后续上板时，只要时序策略变化，优先改这个子模块，不动接收核。

## 4) 内置递增测试源（原码）

```verilog
always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    tx_word           <= {{(SAMPLE_WIDTH-1){1'b0}}, 1'b1};
    tx_shift          <= {SAMPLE_WIDTH{1'b0}};
    expected_data_dbg <= {SAMPLE_WIDTH{1'b0}};
  end else begin
    if (frame_start_s) begin
      expected_data_dbg <= tx_word;
      tx_shift          <= tx_word;
      tx_word           <= tx_word + 1'b1;
    end

    if (bit_tick_s) begin
      tx_shift <= {tx_shift[SAMPLE_WIDTH-2:0], 1'b0};
    end
  end
end
```

解释：

1. 每个新帧到来时，把当前 `tx_word` 装载进 `tx_shift`。
2. 同时把这个值保存到 `expected_data_dbg` 作为本帧期望值。
3. `tx_word` 再自增，留给下一帧。
4. 每个 `bit_tick` 左移 `tx_shift`，完成串行发送。

## 5) 接收核实例与一致性检查（原码）

```verilog
ad7626_min_rx_core #(
  .SAMPLE_WIDTH(SAMPLE_WIDTH),
  .COUNTER_WIDTH(COUNTER_WIDTH)
) u_rx_core (
  .clk(clk),
  .rstn(rstn),
  .frame_start(frame_start_s),
  .bit_tick(bit_tick_s),
  .serial_in(serial_bit_s),
  .sample_valid(sample_valid_s),
  .sample_data(sample_data_s),
  .sample_count(sample_count_s),
  .align_error(align_error_s)
);

always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    mismatch_error <= 1'b0;
  end else if (sample_valid_s && (sample_data_s != expected_data_dbg)) begin
    mismatch_error <= 1'b1;
  end
end
```

解释：

- 串行源输出 `serial_bit_s` 直接喂给接收核，构成闭环。
- 只在 `sample_valid_s` 时比较数据，避免半帧数据误判。
- `mismatch_error` 同样是锁存位，便于快速看是否发生过数据错误。

## 6) 你后续替换到真实 ADC 的改法

把这三处换掉即可，整体框架不动：

1. `serial_in(serial_bit_s)` 改为板级采样位（来自 IOB/IDDR 处理后）。
2. `frame_start_s/bit_tick_s` 改为真实转换时序控制逻辑输出。
3. 保留 `sample_valid/sample_count/align_error/mismatch_error` 作为第一版调试观测口。

## 7) ISE 14.7 / Spartan-6 说明

- 当前版本是纯数字闭环验证顶层，不依赖 Xilinx 原语。
- 上板后建议把该模块拆成：`timing_ctrl` + `io_capture` + `rx_core` 三层，便于约束和时序收敛。
