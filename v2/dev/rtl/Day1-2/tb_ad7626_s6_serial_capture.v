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

module tb_ad7626_s6_serial_capture;

  localparam integer SAMPLE_WIDTH   = 16;
  localparam integer NUM_TEST_WORDS = 5;

  reg                         sys_clk;
  reg                         rstn;
  reg                         read_start_align_r;
  reg                         dco_p_r;
  reg                         dco_n_r;
  reg                         d_p_r;
  reg                         d_n_r;

  wire                        sample_valid;
  wire [SAMPLE_WIDTH-1:0]     sample_data;
  wire                        dco_dbg;
  wire                        data_dbg;

  integer                     internal_word_count_r;
  integer                     sys_word_count_r;

  function [SAMPLE_WIDTH-1:0] expected_word;
    input integer idx;
    begin
      case (idx)
        0: expected_word = 16'hA55A;
        1: expected_word = 16'h8001;
        2: expected_word = 16'h0F0F;
        3: expected_word = 16'h1234;
        4: expected_word = 16'hFEDC;
        default: expected_word = {SAMPLE_WIDTH{1'b0}};
      endcase
    end
  endfunction

  task drive_data_bit;
    input bit_value;
    begin
      d_p_r = bit_value;
      d_n_r = ~bit_value;
    end
  endtask

  task send_word_msb_first;
    input [SAMPLE_WIDTH-1:0] word;
    integer i;
    begin
      read_start_align_r = 1'b1;
      @(posedge sys_clk);
      #1;
      read_start_align_r = 1'b0;

      for (i = SAMPLE_WIDTH - 1; i >= 0; i = i - 1) begin
        drive_data_bit(word[i]);
        #1;
        dco_p_r = 1'b1;
        dco_n_r = 1'b0;
        #1;
        dco_p_r = 1'b0;
        dco_n_r = 1'b1;
      end

      drive_data_bit(1'b0);
      #8;
    end
  endtask

  ad7626_s6_serial_capture #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .BIT_COUNT_WIDTH(6),
    .DROP_FIRST_SAMPLE(0)
  ) dut (
    .sys_clk(sys_clk),
    .rstn(rstn),
    .read_start_align(read_start_align_r),
    .dco_p(dco_p_r),
    .dco_n(dco_n_r),
    .d_p(d_p_r),
    .d_n(d_n_r),
    .sample_valid(sample_valid),
    .sample_data(sample_data),
    .dco_dbg(dco_dbg),
    .data_dbg(data_dbg)
  );

  initial begin
    sys_clk = 1'b0;
    forever #5 sys_clk = ~sys_clk;
  end

  initial begin
    rstn              = 1'b0;
    read_start_align_r = 1'b0;
    dco_p_r           = 1'b0;
    dco_n_r           = 1'b1;
    d_p_r             = 1'b0;
    d_n_r             = 1'b1;
    repeat (4) @(posedge sys_clk);
    rstn = 1'b1;
  end

  initial begin
`ifdef VCD_DUMP
    $dumpfile("tb_ad7626_s6_serial_capture.vcd");
    $dumpvars(0, tb_ad7626_s6_serial_capture);
`endif
  end

  initial begin
    internal_word_count_r = 0;
    sys_word_count_r      = 0;

    @(posedge rstn);
    #20;

    send_word_msb_first(expected_word(0));
    send_word_msb_first(expected_word(1));
    send_word_msb_first(expected_word(2));
    send_word_msb_first(expected_word(3));
    send_word_msb_first(expected_word(4));

    repeat (20) @(posedge sys_clk);

    if (sys_word_count_r != NUM_TEST_WORDS) begin
      $display("[TB_CAPTURE][FAIL] Expected %0d system-domain words, got %0d.",
               NUM_TEST_WORDS, sys_word_count_r);
      $finish;
    end

    $display("[TB_CAPTURE][PASS] Captured %0d words correctly in DCO and sys_clk domains.",
             NUM_TEST_WORDS);
    $finish;
  end

  initial begin
    repeat (5000) @(posedge sys_clk);
    $display("[TB_CAPTURE][FAIL] Timeout: internal=%0d sys=%0d",
             internal_word_count_r, sys_word_count_r);
    $finish;
  end

  always @(dut.sample_toggle_dco) begin
    if (rstn) begin
      if (dut.sample_word_dco !== expected_word(internal_word_count_r)) begin
        $display("[TB_CAPTURE][FAIL] sample_word_dco mismatch at word %0d: got 0x%0h expected 0x%0h",
                 internal_word_count_r, dut.sample_word_dco, expected_word(internal_word_count_r));
        $display("[TB_CAPTURE][INFO] bit_count_dco=%0d shift_reg_dco=0x%0h data_rise_s=%0b",
                 dut.bit_count_dco, dut.shift_reg_dco, dut.data_rise_s);
        $finish;
      end

      internal_word_count_r = internal_word_count_r + 1;
    end
  end

  always @(posedge sys_clk) begin
    if (rstn && sample_valid) begin
      if (sample_data !== expected_word(sys_word_count_r)) begin
        $display("[TB_CAPTURE][FAIL] sample_data mismatch at word %0d: got 0x%0h expected 0x%0h",
                 sys_word_count_r, sample_data, expected_word(sys_word_count_r));
        $display("[TB_CAPTURE][INFO] sample_word_sync=0x%0h sample_word_meta=0x%0h sample_word_dco=0x%0h",
                 dut.sample_word_sync, dut.sample_word_meta, dut.sample_word_dco);
        $finish;
      end

      sys_word_count_r = sys_word_count_r + 1;
    end
  end

endmodule
