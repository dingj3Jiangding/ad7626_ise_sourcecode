# ad7626_min_timing_gen 结合代码说明

对应源码：`v2/dev/rtl/ad7626_min_timing_gen.v`

这个模块做一件事：在 `clk` 时钟域里，生成一帧采样的开始脉冲 `frame_start` 和位采样脉冲 `bit_tick`。

## 1) 先看模块接口（原码）

```verilog
module ad7626_min_timing_gen #(
	parameter integer CNV_PERIOD = 80,
	parameter integer ACQ_DELAY = 4,
	parameter integer SAMPLE_WIDTH = 18,
	parameter integer SCLK_DIV = 2
) (
	input  wire clk,
	input  wire rstn,
	output reg  frame_start,
	output reg  bit_tick,
	output reg  frame_busy
);
```

解释：

- `CNV_PERIOD` 控制“帧与帧之间”的间隔。
- `ACQ_DELAY` 控制 `frame_start` 后，等待多久才开始打 `bit_tick`。
- `SAMPLE_WIDTH` 决定每帧要打多少个 `bit_tick`（默认 18 位）。
- `SCLK_DIV` 决定两个 `bit_tick` 之间隔几个 `clk`。

## 2) 每拍先把脉冲清零（原码）

```verilog
		end else begin
			frame_start <= 1'b0;
			bit_tick    <= 1'b0;
```

解释：

- 这两句保证 `frame_start` 和 `bit_tick` 都是“单周期脉冲”，不会持续拉高。
- 后面的状态判断只在需要的那个时钟拍把脉冲置 1。

## 3) 空闲阶段：计满后启动一帧（原码）

```verilog
			if (!frame_busy) begin
				if (period_cnt == (CNV_PERIOD - 1)) begin
					period_cnt  <= 32'd0;
					acq_cnt     <= 32'd0;
					div_cnt     <= 32'd0;
					bit_cnt     <= 32'd0;
					frame_start <= 1'b1;
					frame_busy  <= 1'b1;
				end else begin
					period_cnt <= period_cnt + 1'b1;
				end
```

解释：

- `frame_busy=0` 表示当前不在采样帧内。
- `period_cnt` 每拍加 1，计到 `CNV_PERIOD-1` 时发出 `frame_start`。
- 一旦发帧开始，进入 `frame_busy=1`，并把帧内用到的计数器都清零。

## 4) 帧内阶段：先等待，再打位脉冲（原码）

```verilog
			end else begin
				if (acq_cnt < ACQ_DELAY) begin
					acq_cnt <= acq_cnt + 1'b1;
				end else if (bit_cnt < SAMPLE_WIDTH) begin
					if (div_cnt == (SCLK_DIV - 1)) begin
						div_cnt   <= 32'd0;
						bit_tick  <= 1'b1;
						bit_cnt   <= bit_cnt + 1'b1;
					end else begin
						div_cnt <= div_cnt + 1'b1;
					end
				end else begin
					frame_busy <= 1'b0;
				end
			end
```

解释：

1. 帧开始后先跑 `acq_cnt`，提供采样前等待窗口。
2. 等待结束后，通过 `div_cnt` 做分频，按 `SCLK_DIV` 周期产生 1 个 `bit_tick`。
3. 每发 1 个 `bit_tick`，`bit_cnt` 加 1。
4. 当 `bit_cnt == SAMPLE_WIDTH`，说明该帧位数已打完，退出 `frame_busy`。

## 5) 用 testbench 参数举个完整时序例子

testbench 里是：

- `CNV_PERIOD = 48`
- `ACQ_DELAY = 4`
- `SCLK_DIV = 2`
- `SAMPLE_WIDTH = 18`

一帧流程可以理解为：

1. 空闲计满 48 个 `clk` 后，`frame_start` 拉高 1 拍。
2. 等待 4 个 `clk`。
3. 之后每隔 2 个 `clk` 产生 1 个 `bit_tick`。
4. 累计产生 18 个 `bit_tick` 后，`frame_busy` 拉低，回到空闲。

## 6) 调参时最容易犯错的点

1. `SAMPLE_WIDTH` 改了但接收核位宽没同步，导致组帧错位。
2. `SCLK_DIV` 太小导致位节拍过快，后级来不及处理。
3. `CNV_PERIOD` 太小导致帧间隔不足，后续真实 ADC 联调时容易出现重叠。

## 7) ISE 14.7 / Spartan-6 说明

- 该模块是纯同步逻辑，不依赖厂商原语。
- 语法保持 Verilog-2001 风格，适合 ISE 14.7 编译。
- 后续上板时，保持该模块接口不变即可快速替换到真实链路中。
