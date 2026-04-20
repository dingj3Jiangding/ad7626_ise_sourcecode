`timescale 1ns/1ps

module ad7626_day1_2_board_top #(
  parameter integer SAMPLE_WIDTH        = 16,
  parameter integer BIT_COUNT_WIDTH   = 6,
  parameter integer COUNTER_WIDTH       = 32,
  parameter integer DATA_SRC_SEL        = 1,
  parameter integer CNV_PERIOD_CYCLES   = 25,
  parameter integer CNV_HIGH_CYCLES     = 5,
  parameter integer MSB_WAIT_CYCLES     = 15,
  parameter integer READ_START_CYCLES   = 15,
  parameter integer READ_PULSE_CYCLES   = 16,
  parameter integer TCLKL_CYCLES        = 10,
  parameter integer DROP_FIRST_SAMPLE   = 1,
  parameter         DIFF_TERM           = "TRUE"
) (
  // This top assumes sys_clk_250 is already a clean 250 MHz fabric clock.
  input  wire                         sys_clk_250,
  input  wire                         rstn,
  input  wire                         dco_p,
  input  wire                         dco_n,
  input  wire                         d_p,
  input  wire                         d_n,
  output wire                         clk_p,
  output wire                         clk_n,
  output wire                         cnv_p,
  output wire                         cnv_n,

  output wire                         sample_valid,
  output wire [SAMPLE_WIDTH-1:0]      sample_data,
  output wire [COUNTER_WIDTH-1:0]     sample_count,
  output wire                         align_error,
  output wire                         mismatch_error,
    
  // Debug signal
  output wire                         frame_start_dbg,
  output wire                         read_start_dbg,
  output wire                         clk_gate_dbg,
  output wire                         read_done_dbg,
  output wire                         hw_mode_dbg,
  output wire                         serial_data_dbg,
  output wire                         adc_dco_dbg,
  output wire                         cnv_dbg,
  output wire [15:0]                  phase_dbg,
  output wire [SAMPLE_WIDTH-1:0]      expected_data_dbg,
  
  // timing debug signal 2026.4.16
  output wire [SAMPLE_WIDTH-1:0]			sample_word_dco_dbg,
  output wire 							data_rise_dbg,
  output wire [BIT_COUNT_WIDTH-1:0] bit_count_dco_dbg,
  output wire [SAMPLE_WIDTH-1:0] shift_reg_dco_dbg
) ;

  wire                        hw_mode_s;
  wire                        cnv_s;
  wire                        clk_gate_s;
  wire                        frame_start_s;
  wire                        read_start_s;
  wire                        read_done_s;
  wire [15:0]                 phase_s;

  wire                        hw_sample_valid_s;
  wire [SAMPLE_WIDTH-1:0]     hw_sample_data_s;
  wire                        hw_data_dbg_s;
  wire                        hw_dco_dbg_s;

  wire                        clk_out_s;
  wire                        cnv_out_s;

  reg  [COUNTER_WIDTH-1:0]    sample_count_r;
  reg                         align_error_r;
  reg                         mismatch_error_r;
  reg                         sample_valid_r;
  reg  [SAMPLE_WIDTH-1:0]     sample_data_r;
  reg  [SAMPLE_WIDTH-1:0]     tx_word_r;
  reg  [SAMPLE_WIDTH-1:0]     tx_shift_r;
  reg  [SAMPLE_WIDTH-1:0]     start_word_r;
  reg  [SAMPLE_WIDTH-1:0]     finish_word_r;
  reg                         start_valid_r;
  reg                         finish_valid_r;
  reg                         ignore_first_frame_r;

  assign hw_mode_s         = (DATA_SRC_SEL != 0);
  assign hw_mode_dbg       = hw_mode_s;
  assign frame_start_dbg   = frame_start_s;
  assign read_start_dbg    = read_start_s;
  assign clk_gate_dbg      = clk_gate_s;
  assign read_done_dbg     = read_done_s;
  assign adc_dco_dbg       = hw_dco_dbg_s;
  assign cnv_dbg           = cnv_s;
  assign phase_dbg         = phase_s;
  
  // if hardware mode, then serial input is hw_data, otherwise it's the MSB of fake input.
  assign serial_data_dbg   = (hw_mode_s) ? hw_data_dbg_s : tx_shift_r[SAMPLE_WIDTH-1];
  assign expected_data_dbg = (finish_valid_r != 0) ? finish_word_r : {SAMPLE_WIDTH{1'b0}};

  assign sample_valid      = sample_valid_r;
  assign sample_data       = sample_data_r;
  assign sample_count      = sample_count_r;
  assign align_error       = align_error_r;
  assign mismatch_error    = mismatch_error_r;

  ad7626_day1_2_timing_gen #(
    .CNV_PERIOD_CYCLES(CNV_PERIOD_CYCLES),
    .CNV_HIGH_CYCLES(CNV_HIGH_CYCLES),
    .MSB_WAIT_CYCLES(MSB_WAIT_CYCLES),
    .READ_START_CYCLES(READ_START_CYCLES),
    .READ_PULSE_CYCLES(READ_PULSE_CYCLES),
    .TCLKL_CYCLES(TCLKL_CYCLES),
    .COUNTER_WIDTH(16)
  ) u_timing_gen (
    .clk(sys_clk_250),
    .rstn(rstn),
    .cnv(cnv_s),
    .clk_gate(clk_gate_s),
    .frame_start(frame_start_s),
    .read_start(read_start_s),
    .read_done(read_done_s),
    .phase_dbg(phase_s)
  );

  ad7626_s6_serial_capture #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .DROP_FIRST_SAMPLE(DROP_FIRST_SAMPLE),
    .DIFF_TERM(DIFF_TERM)
  ) u_serial_capture (
    .sys_clk(sys_clk_250),
    .rstn(rstn),
    .dco_p(dco_p),
    .dco_n(dco_n),
    .d_p(d_p),
    .d_n(d_n),
    .sample_valid(hw_sample_valid_s),
    .sample_data(hw_sample_data_s),
    .dco_dbg(hw_dco_dbg_s),
    .data_dbg(hw_data_dbg_s),

    .read_start_align(read_start_s),
	 
	 // timing debug signal 2026.4.16
	 .sample_word_dco_dbg(sample_word_dco_dbg),
	 .data_rise_dbg(data_rise_dbg),
	 .bit_count_dco_dbg(bit_count_dco_dbg),
	 .shift_reg_dco_dbg(shift_reg_dco_dbg)
  );

  ODDR2 #(
    .DDR_ALIGNMENT("NONE"),
    .INIT(1'b0),
    .SRTYPE("SYNC")
  ) i_clk_oddr2 (
    .Q (clk_out_s),
    .C0(sys_clk_250),
    .C1(~sys_clk_250),
    .CE(1'b1),
    .D0(clk_gate_s),
    .D1(1'b0),
    .R (1'b0),
    .S (1'b0)
  );

  ODDR2 #(
    .DDR_ALIGNMENT("NONE"),
    .INIT(1'b0),
    .SRTYPE("SYNC")
  ) i_cnv_oddr2 (
    .Q (cnv_out_s),
    .C0(sys_clk_250),
    .C1(~sys_clk_250),
    .CE(1'b1),
    .D0(cnv_s),
    .D1(cnv_s),
    .R (1'b0),
    .S (1'b0)
  );

  OBUFDS #(
    .IOSTANDARD("LVDS_25"),
    .SLEW("FAST")
  ) i_clk_obufds (
    .I (clk_out_s),
    .O (clk_p),
    .OB(clk_n)
  );

  OBUFDS #(
    .IOSTANDARD("LVDS_25"),
    .SLEW("FAST")
  ) i_cnv_obufds (
    .I (cnv_out_s),
    .O (cnv_p),
    .OB(cnv_n)
  );

  initial begin
    if (SAMPLE_WIDTH != 16) begin
      $display("[DAY1_2_TOP][WARN] AD7626 echoed-clock mode is expected to deliver 16 bits, but SAMPLE_WIDTH=%0d.", SAMPLE_WIDTH);
    end

    if (READ_START_CYCLES < CNV_HIGH_CYCLES) begin
      $display("[DAY1_2_TOP][WARN] READ_START_CYCLES=%0d begins before CNV returns low at cycle %0d.",
               READ_START_CYCLES, CNV_HIGH_CYCLES);
    end

    if (READ_PULSE_CYCLES != SAMPLE_WIDTH) begin
      $display("[DAY1_2_TOP][WARN] READ_PULSE_CYCLES=%0d does not match SAMPLE_WIDTH=%0d.", READ_PULSE_CYCLES, SAMPLE_WIDTH);
    end

    if ((CNV_HIGH_CYCLES < 3) || (CNV_HIGH_CYCLES > 10)) begin
      $display("[DAY1_2_TOP][WARN] CNV_HIGH_CYCLES=%0d is outside the 250 MHz / 10 ns to 40 ns CNV-high window.", CNV_HIGH_CYCLES);
    end

    if (READ_START_CYCLES < MSB_WAIT_CYCLES) begin
      $display("[DAY1_2_TOP][WARN] The chosen split-burst read slot starts before the current sample is guaranteed ready.");
    end

    if ((CNV_PERIOD_CYCLES - READ_START_CYCLES) > TCLKL_CYCLES) begin
      $display("[DAY1_2_TOP][WARN] Current-cycle burst head exceeds the configured tCLKL budget.");
    end
  end

  always @(posedge sys_clk_250 or negedge rstn) begin
    if (!rstn) begin
      tx_word_r           <= {{(SAMPLE_WIDTH-1){1'b0}}, 1'b1};
      tx_shift_r          <= {SAMPLE_WIDTH{1'b0}};
      start_word_r        <= {SAMPLE_WIDTH{1'b0}};
      finish_word_r       <= {SAMPLE_WIDTH{1'b0}};
      start_valid_r       <= 1'b0;
      finish_valid_r      <= 1'b0;

      sample_valid_r      <= 1'b0;
      sample_data_r       <= {SAMPLE_WIDTH{1'b0}};
      sample_count_r      <= {COUNTER_WIDTH{1'b0}};

      align_error_r       <= 1'b0;
      mismatch_error_r    <= 1'b0;
      ignore_first_frame_r <= ((DATA_SRC_SEL != 0) && (DROP_FIRST_SAMPLE != 0));
    end else begin
      sample_valid_r <= 1'b0;

      if (frame_start_s) begin
        finish_word_r  <= start_word_r;
        finish_valid_r <= start_valid_r;

        if (ignore_first_frame_r) begin
          ignore_first_frame_r <= 1'b0;
          start_word_r         <= tx_word_r;
          start_valid_r        <= 1'b0;
        end else begin
          start_word_r   <= tx_word_r;
          start_valid_r  <= 1'b1;
          tx_word_r      <= tx_word_r + 1'b1;
        end
      end

      if (!hw_mode_s && read_start_s) begin
        if (start_valid_r) begin
          tx_shift_r <= start_word_r;
        end else begin
          tx_shift_r <= {SAMPLE_WIDTH{1'b0}};
        end
      end else if (!hw_mode_s && clk_gate_s) begin
        tx_shift_r <= {tx_shift_r[SAMPLE_WIDTH-2:0], 1'b0};
      end

      if (hw_mode_s) begin
        if (hw_sample_valid_s) begin
          sample_valid_r <= 1'b1;
          sample_data_r  <= hw_sample_data_s;
          sample_count_r <= sample_count_r + 1'b1;

          if (!finish_valid_r) begin
            align_error_r <= 1'b1;
          end
        end
      end else begin
        if (read_done_s && finish_valid_r) begin
          sample_valid_r <= 1'b1;
          sample_data_r  <= finish_word_r;
          sample_count_r <= sample_count_r + 1'b1;
        end
      end
    end
  end

endmodule
