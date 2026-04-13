`timescale 1ns/1ps

module ad7626_min_loopback_top #(
  parameter integer SAMPLE_WIDTH = 18,
  parameter integer COUNTER_WIDTH = 32,
  parameter integer CNV_PERIOD = 80,
  parameter integer ACQ_DELAY = 4,
  parameter integer SCLK_DIV = 2
) (
  input  wire                         clk,
  input  wire                         rstn,
  output wire                         sample_valid,
  output wire [SAMPLE_WIDTH-1:0]      sample_data,
  output wire [COUNTER_WIDTH-1:0]     sample_count,
  output wire                         align_error,
  output reg                          mismatch_error,
  output wire                         frame_start_dbg,
  output wire                         bit_tick_dbg,
  output wire                         serial_data_dbg,
  output reg  [SAMPLE_WIDTH-1:0]      expected_data_dbg
);

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

  assign serial_bit_s    = tx_shift[SAMPLE_WIDTH-1];        // 'MSB-first' take the highest bit of tx_shift
  assign serial_data_dbg = serial_bit_s;

  assign sample_valid    = sample_valid_s;
  assign sample_data     = sample_data_s;
  assign sample_count    = sample_count_s;
  assign align_error     = align_error_s;
  assign frame_start_dbg = frame_start_s;
  assign bit_tick_dbg    = bit_tick_s;

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


// This part is creating a fake ADC for testing
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      tx_word           <= {{(SAMPLE_WIDTH-1){1'b0}}, 1'b1};
      tx_shift          <= {SAMPLE_WIDTH{1'b0}};
      expected_data_dbg <= {SAMPLE_WIDTH{1'b0}};
    end else begin
      if (frame_start_s) begin              
        expected_data_dbg <= tx_word;
        tx_shift          <= tx_word;
        tx_word           <= tx_word + 1'b1;  // tx_word is a test sample, adding 1 to itself 
      end                                     // for maintaining a unchanged(shifted) reference

      if (bit_tick_s) begin
        tx_shift <= {tx_shift[SAMPLE_WIDTH-2:0], 1'b0};
      end
    end
  end

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

endmodule
