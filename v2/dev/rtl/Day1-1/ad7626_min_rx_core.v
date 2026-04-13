`timescale 1ns/1ps

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

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      capture_active <= 1'b0;
      bit_count      <= {BIT_COUNT_W{1'b0}};
      shift_reg      <= {SAMPLE_WIDTH{1'b0}};
      sample_valid   <= 1'b0;
      sample_data    <= {SAMPLE_WIDTH{1'b0}};
      sample_count   <= {COUNTER_WIDTH{1'b0}};
      align_error    <= 1'b0;
    end else begin
      sample_valid <= 1'b0;

      if (frame_start) begin
        if (capture_active) begin
          align_error <= 1'b1;
        end
        capture_active <= 1'b1;
        bit_count      <= {BIT_COUNT_W{1'b0}};
        shift_reg      <= {SAMPLE_WIDTH{1'b0}};
      end

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
    end
  end

endmodule
