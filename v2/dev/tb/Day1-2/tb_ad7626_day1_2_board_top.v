`timescale 1ns/1ps

// Generic simulation stubs for early verification.
// When using ISE + UNISIM libraries, compile with USE_XILINX_UNISIM defined.
`ifndef USE_XILINX_UNISIM
module IBUFDS #(
  parameter DIFF_TERM    = "FALSE",
  parameter IBUF_LOW_PWR = "TRUE",
  parameter IOSTANDARD   = "DEFAULT"
) (
  output wire O,
  input  wire I,
  input  wire IB
);
  assign O = I;
endmodule

module IBUFGDS #(
  parameter DIFF_TERM    = "FALSE",
  parameter IBUF_LOW_PWR = "TRUE",
  parameter IOSTANDARD   = "DEFAULT"
) (
  output wire O,
  input  wire I,
  input  wire IB
);
  assign O = I;
endmodule

module OBUFDS #(
  parameter IOSTANDARD = "DEFAULT",
  parameter SLEW       = "SLOW"
) (
  input  wire I,
  output wire O,
  output wire OB
);
  assign O  = I;
  assign OB = ~I;
endmodule

module ODDR2 #(
  parameter DDR_ALIGNMENT = "NONE",
  parameter INIT          = 1'b0,
  parameter SRTYPE        = "SYNC"
) (
  output reg  Q,
  input  wire C0,
  input  wire C1,
  input  wire CE,
  input  wire D0,
  input  wire D1,
  input  wire R,
  input  wire S
);
  initial begin
    Q = INIT;
  end

  always @(posedge C0 or posedge R or posedge S) begin
    if (R) begin
      Q <= 1'b0;
    end else if (S) begin
      Q <= 1'b1;
    end else if (CE) begin
      Q <= D0;
    end
  end

  always @(posedge C1 or posedge R or posedge S) begin
    if (R) begin
      Q <= 1'b0;
    end else if (S) begin
      Q <= 1'b1;
    end else if (CE) begin
      Q <= D1;
    end
  end
endmodule

module IDDR2 #(
  parameter DDR_ALIGNMENT = "NONE",
  parameter INIT_Q0       = 1'b0,
  parameter INIT_Q1       = 1'b0,
  parameter SRTYPE        = "SYNC"
) (
  output reg  Q0,
  output reg  Q1,
  input  wire C0,
  input  wire C1,
  input  wire CE,
  input  wire D,
  input  wire R,
  input  wire S
);
  initial begin
    Q0 = INIT_Q0;
    Q1 = INIT_Q1;
  end

  always @(posedge C0 or posedge R or posedge S) begin
    if (R) begin
      Q0 <= 1'b0;
    end else if (S) begin
      Q0 <= 1'b1;
    end else if (CE) begin
      Q0 <= D;
    end
  end

  always @(posedge C1 or posedge R or posedge S) begin
    if (R) begin
      Q1 <= 1'b0;
    end else if (S) begin
      Q1 <= 1'b1;
    end else if (CE) begin
      Q1 <= D;
    end
  end
endmodule
`endif

module tb_ad7626_day1_2_board_top;

  localparam integer SAMPLE_WIDTH              = 16;
  localparam integer TARGET_VALID_SAMPLES      = 16;
  localparam integer CNV_PERIOD_CYCLES         = 25;
  localparam integer CNV_HIGH_CYCLES           = 5;
  localparam integer MSB_WAIT_CYCLES           = 15;
  localparam integer READ_START_CYCLES         = 15;
  localparam integer READ_PULSE_CYCLES         = 16;
  localparam integer TCLKL_CYCLES              = 10;
  localparam integer READ_HEAD_CYCLES          = CNV_PERIOD_CYCLES - READ_START_CYCLES;
  localparam integer READ_TAIL_CYCLES          = READ_PULSE_CYCLES - READ_HEAD_CYCLES;

  reg                         sys_clk_250;
  reg                         rstn;
  reg                         d_p_r;
  reg                         d_n_r;

  wire                        dco_p;
  wire                        dco_n;
  wire                        clk_p;
  wire                        clk_n;
  wire                        cnv_p;
  wire                        cnv_n;
  wire                        sample_valid;
  wire [SAMPLE_WIDTH-1:0]     sample_data;
  wire [31:0]                 sample_count;
  wire                        align_error;
  wire                        mismatch_error;
  wire                        frame_start_dbg;
  wire                        read_start_dbg;
  wire                        clk_gate_dbg;
  wire                        read_done_dbg;
  wire                        hw_mode_dbg;
  wire                        serial_data_dbg;
  wire                        adc_dco_dbg;
  wire                        cnv_dbg;
  wire [15:0]                 phase_dbg;
  wire [SAMPLE_WIDTH-1:0]     expected_data_dbg;

  reg  [SAMPLE_WIDTH-1:0]     adc_shift_word_r;
  reg  [SAMPLE_WIDTH-1:0]     next_cycle_word_r;
  reg  [SAMPLE_WIDTH-1:0]     next_valid_word_r;
  reg                         adc_first_conversion_invalid_r;
  integer                     adc_negedge_count_r;

  integer                     frame_index_r;
  integer                     cnv_high_cycles_seen_r;
  integer                     clk_gate_cycles_seen_r;
  integer                     valid_sample_seen_r;
  reg  [SAMPLE_WIDTH-1:0]     expected_sample_r;

  assign dco_p = clk_p;
  assign dco_n = clk_n;

  ad7626_day1_2_board_top #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .COUNTER_WIDTH(32),
    .DATA_SRC_SEL(1),
    .CNV_PERIOD_CYCLES(CNV_PERIOD_CYCLES),
    .CNV_HIGH_CYCLES(CNV_HIGH_CYCLES),
    .MSB_WAIT_CYCLES(MSB_WAIT_CYCLES),
    .READ_START_CYCLES(READ_START_CYCLES),
    .READ_PULSE_CYCLES(READ_PULSE_CYCLES),
    .TCLKL_CYCLES(TCLKL_CYCLES),
    .DROP_FIRST_SAMPLE(1)
  ) dut (
    .sys_clk_250(sys_clk_250),
    .rstn(rstn),
    .dco_p(dco_p),
    .dco_n(dco_n),
    .d_p(d_p_r),
    .d_n(d_n_r),
    .clk_p(clk_p),
    .clk_n(clk_n),
    .cnv_p(cnv_p),
    .cnv_n(cnv_n),
    .sample_valid(sample_valid),
    .sample_data(sample_data),
    .sample_count(sample_count),
    .align_error(align_error),
    .mismatch_error(mismatch_error),
    .frame_start_dbg(frame_start_dbg),
    .read_start_dbg(read_start_dbg),
    .clk_gate_dbg(clk_gate_dbg),
    .read_done_dbg(read_done_dbg),
    .hw_mode_dbg(hw_mode_dbg),
    .serial_data_dbg(serial_data_dbg),
    .adc_dco_dbg(adc_dco_dbg),
    .cnv_dbg(cnv_dbg),
    .phase_dbg(phase_dbg),
    .expected_data_dbg(expected_data_dbg)
  );

  initial begin
    sys_clk_250 = 1'b0;
    forever #2 sys_clk_250 = ~sys_clk_250;
  end

  initial begin
    rstn = 1'b0;
    d_p_r = 1'b0;
    d_n_r = 1'b1;
    repeat (20) @(posedge sys_clk_250);
    rstn = 1'b1;
  end

  initial begin
`ifdef VCD_DUMP
    $dumpfile("tb_ad7626_day1_2_board_top.vcd");
    $dumpvars(0, tb_ad7626_day1_2_board_top);
`endif
  end

  initial begin
    repeat (50000) @(posedge sys_clk_250);
    $display("[TB][FAIL] Timeout: sample_count=%0d frame_index=%0d phase=%0d",
             sample_count, frame_index_r, phase_dbg);
    $finish;
  end

  // Simplified AD7626 behavioral model for echoed-clock mode:
  // 1. Cycle N launches conversion N on CNV rising.
  // 2. Phase 15..24 of cycle N shifts the first 10 bits of sample N.
  // 3. Phase 0..5 of cycle N+1 shifts the last 6 bits of sample N.
  // 4. The first conversion result after reset is invalid.
  // 5. DCO is modeled as an echoed copy of CLK.
  // 6. D is valid before each rising DCO edge and updates on falling DCO edge.
  always @(posedge cnv_p or negedge rstn) begin
    if (!rstn) begin
      adc_shift_word_r    <= {SAMPLE_WIDTH{1'b0}};
      next_cycle_word_r   <= {{(SAMPLE_WIDTH-1){1'b0}}, 1'b1};
      next_valid_word_r   <= {{(SAMPLE_WIDTH-1){1'b0}}, 1'b1};
      adc_first_conversion_invalid_r <= 1'b1;
      adc_negedge_count_r <= SAMPLE_WIDTH;
      d_p_r               <= 1'b0;
      d_n_r               <= 1'b1;
    end else begin
      if (adc_first_conversion_invalid_r) begin
        adc_shift_word_r    <= 16'hDEAD;
        d_p_r               <= 1'b1;
        d_n_r               <= 1'b0;
        adc_first_conversion_invalid_r <= 1'b0;
      end else begin
        adc_shift_word_r    <= next_cycle_word_r;
        d_p_r               <= next_cycle_word_r[SAMPLE_WIDTH-1];
        d_n_r               <= ~next_cycle_word_r[SAMPLE_WIDTH-1];
        next_cycle_word_r   <= next_valid_word_r + 1'b1;
        next_valid_word_r   <= next_valid_word_r + 1'b1;
      end
      adc_negedge_count_r <= 0;
    end
  end

  always @(negedge clk_p or negedge rstn) begin
    if (!rstn) begin
      adc_negedge_count_r <= SAMPLE_WIDTH;
      d_p_r               <= 1'b0;
      d_n_r               <= 1'b1;
    end else if (adc_negedge_count_r < SAMPLE_WIDTH) begin
      if (adc_negedge_count_r == (SAMPLE_WIDTH - 1)) begin
        adc_negedge_count_r <= adc_negedge_count_r + 1;
        d_p_r               <= 1'b0;
        d_n_r               <= 1'b1;
      end else begin
        adc_negedge_count_r <= adc_negedge_count_r + 1;
        d_p_r               <= adc_shift_word_r[SAMPLE_WIDTH-2];
        d_n_r               <= ~adc_shift_word_r[SAMPLE_WIDTH-2];
        adc_shift_word_r    <= {adc_shift_word_r[SAMPLE_WIDTH-2:0], 1'b0};
      end
    end
  end

  always @(posedge sys_clk_250) begin
    if (!rstn) begin
      frame_index_r            = 0;
      cnv_high_cycles_seen_r   = 0;
      clk_gate_cycles_seen_r   = 0;
      valid_sample_seen_r      = 0;
      expected_sample_r        = {{(SAMPLE_WIDTH-1){1'b0}}, 1'b1};
    end else begin
      if (!hw_mode_dbg) begin
        $display("[TB][FAIL] DUT is not in hardware mode.");
        $finish;
      end

      if (align_error) begin
        $display("[TB][FAIL] Align error at sample_count=%0d frame=%0d phase=%0d",
                 sample_count, frame_index_r, phase_dbg);
        $finish;
      end

      if (mismatch_error) begin
        $display("[TB][FAIL] Mismatch error should stay low in hw mode.");
        $finish;
      end

      if (frame_start_dbg) begin
        if (phase_dbg != 16'd0) begin
          $display("[TB][FAIL] frame_start asserted at phase=%0d instead of 0.",
                   phase_dbg);
          $finish;
        end

        if (frame_index_r != 0) begin
          if (cnv_high_cycles_seen_r != CNV_HIGH_CYCLES) begin
            $display("[TB][FAIL] CNV high count mismatch: got %0d expected %0d on frame %0d",
                     cnv_high_cycles_seen_r, CNV_HIGH_CYCLES, frame_index_r);
            $finish;
          end

          if (clk_gate_cycles_seen_r != READ_PULSE_CYCLES) begin
            $display("[TB][FAIL] clk_gate count mismatch: got %0d expected %0d on frame %0d",
                     clk_gate_cycles_seen_r, READ_PULSE_CYCLES, frame_index_r);
            $finish;
          end
        end

        frame_index_r          = frame_index_r + 1;
        cnv_high_cycles_seen_r = (cnv_dbg) ? 1 : 0;
        clk_gate_cycles_seen_r = (clk_gate_dbg) ? 1 : 0;
      end else begin
        if (cnv_dbg) begin
          cnv_high_cycles_seen_r = cnv_high_cycles_seen_r + 1;
        end

        if (clk_gate_dbg) begin
          clk_gate_cycles_seen_r = clk_gate_cycles_seen_r + 1;
        end
      end

      if (read_start_dbg && (phase_dbg != READ_START_CYCLES[15:0])) begin
        $display("[TB][FAIL] read_start asserted at phase=%0d expected %0d.",
                 phase_dbg, READ_START_CYCLES);
        $finish;
      end

      if (read_done_dbg && (phase_dbg != READ_TAIL_CYCLES[15:0])) begin
        $display("[TB][FAIL] read_done asserted at phase=%0d expected %0d.",
                 phase_dbg, READ_TAIL_CYCLES);
        $finish;
      end

      if (clk_gate_dbg !== ((phase_dbg >= READ_START_CYCLES[15:0]) ||
                            (phase_dbg < READ_TAIL_CYCLES[15:0]))) begin
        $display("[TB][FAIL] clk_gate mismatch at phase=%0d.", phase_dbg);
        $finish;
      end

      if (sample_valid) begin
        valid_sample_seen_r = valid_sample_seen_r + 1;

        if (sample_data !== expected_sample_r) begin
          $display("[TB][FAIL] Sample mismatch: got 0x%0h expected 0x%0h at valid_sample=%0d",
                   sample_data, expected_sample_r, valid_sample_seen_r);
          $finish;
        end

        expected_sample_r = expected_sample_r + 1'b1;

        if (valid_sample_seen_r == TARGET_VALID_SAMPLES) begin
          $display("[TB][PASS] Reached %0d valid hardware samples with correct timing and data.",
                   TARGET_VALID_SAMPLES);
          $finish;
        end
      end
    end
  end

endmodule
