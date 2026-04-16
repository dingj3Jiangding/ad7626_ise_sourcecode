`timescale 1ns/1ps

module ad7626_day1_2_board_top_100m #(
  parameter integer SAMPLE_WIDTH        = 16,
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
  input  wire                         sys_clk_100,
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
  output wire                         clkgen_locked_dbg
) ;

  wire clk_250_s;
  wire core_rstn_s;

  ad7626_day1_2_clkgen_100m_to_250m u_clkgen (
    .clk_100_in(sys_clk_100),
    .rstn(rstn),
    .clk_250_out(clk_250_s),
    .locked(clkgen_locked_dbg)
  );

  assign core_rstn_s = rstn & clkgen_locked_dbg;

  ad7626_day1_2_board_top #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .COUNTER_WIDTH(COUNTER_WIDTH),
    .DATA_SRC_SEL(DATA_SRC_SEL),
    .CNV_PERIOD_CYCLES(CNV_PERIOD_CYCLES),
    .CNV_HIGH_CYCLES(CNV_HIGH_CYCLES),
    .MSB_WAIT_CYCLES(MSB_WAIT_CYCLES),
    .READ_START_CYCLES(READ_START_CYCLES),
    .READ_PULSE_CYCLES(READ_PULSE_CYCLES),
    .TCLKL_CYCLES(TCLKL_CYCLES),
    .DROP_FIRST_SAMPLE(DROP_FIRST_SAMPLE),
    .DIFF_TERM(DIFF_TERM)
  ) u_board_top_core (
    .sys_clk_250(clk_250_s),
    .rstn(core_rstn_s),
    .dco_p(dco_p),
    .dco_n(dco_n),
    .d_p(d_p),
    .d_n(d_n),
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

endmodule
