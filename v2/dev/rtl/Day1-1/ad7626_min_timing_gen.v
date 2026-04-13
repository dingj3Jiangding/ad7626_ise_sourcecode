`timescale 1ns/1ps

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

  reg [31:0] period_cnt;
  reg [31:0] acq_cnt;
  reg [31:0] div_cnt;
  reg [31:0] bit_cnt;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      period_cnt   <= 32'd0;
      acq_cnt      <= 32'd0;
      div_cnt      <= 32'd0;
      bit_cnt      <= 32'd0;
      frame_start  <= 1'b0;
      bit_tick     <= 1'b0;
      frame_busy   <= 1'b0;
    end else begin
      frame_start <= 1'b0;
      bit_tick    <= 1'b0;

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
    end
  end

endmodule
