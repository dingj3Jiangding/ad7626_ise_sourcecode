# ad7626_min_rx_core 结合代码说明

对应源码：`v2/dev/rtl/ad7626_min_rx_core.v`

这个模块是“串行位流 -> 并行样本”的核心接收器。

## 1) 先看接口与内部状态（原码）

```verilog
module ad7626_min_rx_core #(
  parameter integer SAMPLE_WIDTH = 18,
  parameter integer COUNTER_WIDTH = 32,
  parameter integer BIT_COUNT_W = 6
) (
  input  wire                         clk,
  input  wire                         rstn,
  input  wire                         frame_start,
  input  wire                         bit_tick,
  input  wire                         serial_in,
  output reg                          sample_valid,
  output reg  [SAMPLE_WIDTH-1:0]      sample_data,
  output reg  [COUNTER_WIDTH-1:0]     sample_count,
  output reg                          align_error
);

reg                              capture_active;
reg [BIT_COUNT_W-1:0]            bit_count;
reg [SAMPLE_WIDTH-1:0]           shift_reg;
```

解释：

- `capture_active`：当前是否在接收一帧样本。
- `bit_count`：本帧已经接了多少位。
- `shift_reg`：串行移位缓存。

## 2) 帧开始处理（原码）

```verilog
      if (frame_start) begin
        if (capture_active) begin
          align_error <= 1'b1;
        end
        capture_active <= 1'b1;
        bit_count      <= {BIT_COUNT_W{1'b0}};
        shift_reg      <= {SAMPLE_WIDTH{1'b0}};
      end
```

解释：

1. `frame_start` 到来就进入捕获态。
2. 如果上一帧还没结束（`capture_active=1`），说明节拍冲突，置 `align_error`。
3. 新帧开始时清空位计数和移位寄存器。

## 3) 每个 bit_tick 的移位与计数（原码）

```verilog
      if (bit_tick) begin
        if (!capture_active) begin
          align_error <= 1'b1;
        end else begin
          shift_reg <= {shift_reg[SAMPLE_WIDTH-2:0], serial_in};
          if (bit_count == (SAMPLE_WIDTH - 1)) begin
            sample_data    <= {shift_reg[SAMPLE_WIDTH-2:0], serial_in};
            sample_valid   <= 1'b1;
            sample_count   <= sample_count + 1'b1;
            capture_active <= 1'b0;
            bit_count      <= {BIT_COUNT_W{1'b0}};
          end else begin
            bit_count <= bit_count + 1'b1;
          end
        end
      end
```

解释：

- `shift_reg <= {..., serial_in}` 表示每来一位都左移并把新位塞到 LSB。
- 到最后一位时，`sample_data` 直接拼 `{旧 shift_reg, 当前 serial_in}`，避免受非阻塞赋值时序影响。
- 一帧结束时：
  - `sample_valid` 拉高 1 拍。
  - `sample_count` 加 1。
  - `capture_active` 拉低，等待下一帧。

## 4) 一个 4 位样本的小例子

假设 `SAMPLE_WIDTH=4`，串行输入顺序是 `1 0 1 1`（MSB first）：

1. 第 1 个 `bit_tick`：`shift_reg = 0001`
2. 第 2 个 `bit_tick`：`shift_reg = 0010`
3. 第 3 个 `bit_tick`：`shift_reg = 0101`
4. 第 4 个 `bit_tick`：输出 `sample_data = 1011`，并拉高 `sample_valid`

这和 testbench 的“MSB-first 串行源”是配套的。

## 5) 错误位 align_error 的意义

`align_error` 在两种情况下置 1：

1. 上一帧未结束又收到 `frame_start`。
2. 不在捕获态却收到 `bit_tick`。

它是锁存位（置 1 后不自动清零），目的是在联调时保留“曾经出错”的痕迹。

## 6) ISE 14.7 / Spartan-6 说明

- 使用 `BIT_COUNT_W` 显式参数，避免依赖 `$clog2`。
- 若你把 `SAMPLE_WIDTH` 改到 32 以上，需要同步增大 `BIT_COUNT_W`。
- 该模块本身不依赖厂商原语，适合作为后续板级版本的可复用核心。
