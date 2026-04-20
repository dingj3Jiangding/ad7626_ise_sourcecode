`timescale 1ns/1ps

module ad7626_day1_2_timing_gen #(
  parameter integer CNV_PERIOD_CYCLES = 25,   // 100ns
  parameter integer CNV_HIGH_CYCLES   = 5,    // 20ns
  parameter integer MSB_WAIT_CYCLES   = 15,   // 60ns
  parameter integer READ_START_CYCLES = 15,   // 60ns
  parameter integer READ_PULSE_CYCLES = 17,   // 68ns
  parameter integer TCLKL_CYCLES      = 10,   // 40ns
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

  localparam integer READ_HEAD_CYCLES     = CNV_PERIOD_CYCLES - READ_START_CYCLES;
  localparam integer READ_TAIL_CYCLES     = READ_PULSE_CYCLES - READ_HEAD_CYCLES;

  reg [COUNTER_WIDTH-1:0] phase_cnt;

  initial begin
    if (CNV_PERIOD_CYCLES <= 0) begin
      $display("[TIMING_GEN][WARN] CNV_PERIOD_CYCLES should be greater than 0.");
    end

    if (CNV_HIGH_CYCLES <= 0) begin
      $display("[TIMING_GEN][WARN] CNV_HIGH_CYCLES should be greater than 0.");
    end

    if (READ_PULSE_CYCLES <= 0) begin
      $display("[TIMING_GEN][WARN] READ_PULSE_CYCLES should be greater than 0.");
    end

    if (MSB_WAIT_CYCLES <= CNV_HIGH_CYCLES) begin
      $display("[TIMING_GEN][WARN] MSB_WAIT_CYCLES should be larger than CNV_HIGH_CYCLES.");
    end

    if (READ_START_CYCLES < CNV_HIGH_CYCLES) begin
      $display("[TIMING_GEN][WARN] READ_START_CYCLES should not begin before CNV returns low.");
    end

    if (READ_START_CYCLES >= CNV_PERIOD_CYCLES) begin
      $display("[TIMING_GEN][WARN] READ_START_CYCLES should stay inside the cycle.");
    end

    if (READ_START_CYCLES < MSB_WAIT_CYCLES) begin
      $display("[TIMING_GEN][WARN] Split-burst read starts before the sample is guaranteed ready.");
    end

    if (READ_HEAD_CYCLES <= 0) begin
      $display("[TIMING_GEN][WARN] READ_HEAD_CYCLES=%0d is invalid. READ_START_CYCLES is too late.",
               READ_HEAD_CYCLES);
    end

    if (READ_TAIL_CYCLES <= 0) begin
      $display("[TIMING_GEN][WARN] READ_TAIL_CYCLES=%0d is invalid. READ_PULSE_CYCLES does not cross into the next cycle.",
               READ_TAIL_CYCLES);
    end

    if (READ_HEAD_CYCLES > TCLKL_CYCLES) begin
      $display("[TIMING_GEN][WARN] READ_HEAD_CYCLES=%0d exceeds the current-cycle tCLKL budget=%0d.",
               READ_HEAD_CYCLES, TCLKL_CYCLES);
    end

    if (READ_HEAD_CYCLES != TCLKL_CYCLES) begin
      $display("[TIMING_GEN][WARN] Current-cycle burst head=%0d cycles, while TCLKL_CYCLES = %0d.",
               READ_HEAD_CYCLES, TCLKL_CYCLES);
    end

    if (READ_START_CYCLES != MSB_WAIT_CYCLES) begin
      $display("[TIMING_GEN][WARN] READ_START_CYCLES=%0d does not match MSB_WAIT_CYCLES=%0d in the current same-cycle split-burst model.",
               READ_START_CYCLES, MSB_WAIT_CYCLES);
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
      read_start  <= (phase_cnt == READ_START_CYCLES[COUNTER_WIDTH-1:0]);
      read_done   <= (phase_cnt == READ_TAIL_CYCLES[COUNTER_WIDTH-1:0]);
      cnv         <= (phase_cnt < CNV_HIGH_CYCLES);
      clk_gate    <= ((phase_cnt >= READ_START_CYCLES) ||
                      (phase_cnt < READ_TAIL_CYCLES));
      phase_dbg   <= phase_cnt;

      if (phase_cnt == (CNV_PERIOD_CYCLES - 1)) begin
        phase_cnt <= {COUNTER_WIDTH{1'b0}};
      end else begin
        phase_cnt <= phase_cnt + 1'b1;
      end
    end
  end

endmodule
