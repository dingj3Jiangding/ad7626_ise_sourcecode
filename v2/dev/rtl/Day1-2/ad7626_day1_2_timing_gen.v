`timescale 1ns/1ps

module ad7626_day1_2_timing_gen #(
  parameter integer CNV_PERIOD_CYCLES = 60,
  parameter integer CNV_HIGH_CYCLES   = 5,
  parameter integer MSB_WAIT_CYCLES   = 25,
  parameter integer READ_PULSE_CYCLES = 16,
  parameter integer POST_READ_GUARD_MIN_CYCLES = 18,
  parameter integer COUNTER_WIDTH     = 16
) (
  input  wire                     clk,
  input  wire                     rstn,
  output reg                      cnv,
  output reg                      clk_gate,
  output reg                      frame_start,
  output reg                      read_start,
  output reg                      read_done,
  output reg  [COUNTER_WIDTH-1:0] phase_dbg
);

  localparam integer READ_END_CYCLES        = MSB_WAIT_CYCLES + READ_PULSE_CYCLES;
  localparam integer POST_READ_GUARD_CYCLES = CNV_PERIOD_CYCLES - READ_END_CYCLES;

  reg [COUNTER_WIDTH-1:0] phase_cnt;

  initial begin
    if (CNV_HIGH_CYCLES <= 0) begin
      $display("[TIMING_GEN][WARN] CNV_HIGH_CYCLES should be greater than 0.");
    end

    if (READ_PULSE_CYCLES <= 0) begin
      $display("[TIMING_GEN][WARN] READ_PULSE_CYCLES should be greater than 0.");
    end

    if (MSB_WAIT_CYCLES <= CNV_HIGH_CYCLES) begin
      $display("[TIMING_GEN][WARN] MSB_WAIT_CYCLES should be larger than CNV_HIGH_CYCLES.");
    end

    if (READ_END_CYCLES >= CNV_PERIOD_CYCLES) begin
      $display("[TIMING_GEN][WARN] READ window reaches or exceeds the conversion period end.");
    end

    if (POST_READ_GUARD_CYCLES < 0) begin
      $display("[TIMING_GEN][WARN] POST_READ_GUARD_CYCLES is negative. Parameters are invalid.");
    end else if (POST_READ_GUARD_CYCLES < POST_READ_GUARD_MIN_CYCLES) begin
      $display("[TIMING_GEN][WARN] Post-read guard is only %0d cycles, below the recommended %0d-cycle minimum.",
               POST_READ_GUARD_CYCLES, POST_READ_GUARD_MIN_CYCLES);
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      phase_cnt    <= {COUNTER_WIDTH{1'b0}};
      cnv          <= 1'b0;
      clk_gate     <= 1'b0;
      frame_start  <= 1'b0;
      read_start   <= 1'b0;
      read_done    <= 1'b0;
      phase_dbg    <= {COUNTER_WIDTH{1'b0}};
    end else begin
      frame_start <= (phase_cnt == {COUNTER_WIDTH{1'b0}});
      read_start  <= (phase_cnt == MSB_WAIT_CYCLES[COUNTER_WIDTH-1:0]);
      read_done   <= (phase_cnt == READ_END_CYCLES[COUNTER_WIDTH-1:0]);
      cnv         <= (phase_cnt < CNV_HIGH_CYCLES);
      clk_gate    <= ((phase_cnt >= MSB_WAIT_CYCLES) &&
                      (phase_cnt < READ_END_CYCLES));
      phase_dbg   <= phase_cnt;

      if (phase_cnt == (CNV_PERIOD_CYCLES - 1)) begin
        phase_cnt <= {COUNTER_WIDTH{1'b0}};
      end else begin
        phase_cnt <= phase_cnt + 1'b1;
      end
    end
  end

endmodule
