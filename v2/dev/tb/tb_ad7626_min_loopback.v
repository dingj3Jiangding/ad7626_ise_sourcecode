`timescale 1ns/1ps

module tb_ad7626_min_loopback;

  localparam integer SAMPLE_WIDTH   = 18;
  localparam integer TARGET_SAMPLES = 128;

  reg clk;
  reg rstn;

  wire                        sample_valid;
  wire [SAMPLE_WIDTH-1:0]     sample_data;
  wire [31:0]                 sample_count;
  wire                        align_error;
  wire                        mismatch_error;
  wire                        frame_start_dbg;
  wire                        bit_tick_dbg;
  wire                        serial_data_dbg;
  wire [SAMPLE_WIDTH-1:0]     expected_data_dbg;

  ad7626_min_loopback_top #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .COUNTER_WIDTH(32),
    .CNV_PERIOD(48),
    .ACQ_DELAY(4),
    .SCLK_DIV(2)
  ) dut (
    .clk(clk),
    .rstn(rstn),
    .sample_valid(sample_valid),
    .sample_data(sample_data),
    .sample_count(sample_count),
    .align_error(align_error),
    .mismatch_error(mismatch_error),
    .frame_start_dbg(frame_start_dbg),
    .bit_tick_dbg(bit_tick_dbg),
    .serial_data_dbg(serial_data_dbg),
    .expected_data_dbg(expected_data_dbg)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rstn = 1'b0;
    repeat (20) @(posedge clk);
    rstn = 1'b1;
  end

  initial begin
`ifdef VCD_DUMP
    $dumpfile("tb_ad7626_min_loopback.vcd");
    $dumpvars(0, tb_ad7626_min_loopback);
`endif
  end

  // 超时保护：防止 testbench 卡住不退出。
  initial begin
    repeat (200000) @(posedge clk);
    $display("[TB][FAIL] Timeout: sample_count=%0d", sample_count);
    $finish;
  end

  always @(posedge clk) begin
    if (!rstn) begin
      // no-op
    end else begin
      if (align_error) begin
        $display("[TB][FAIL] Align error at sample_count=%0d", sample_count);
        $finish;
      end

      if (mismatch_error) begin
        $display("[TB][FAIL] Data mismatch at sample_count=%0d data=0x%0h expected=0x%0h",
                 sample_count, sample_data, expected_data_dbg);
        $finish;
      end

      if (sample_valid && (sample_count == TARGET_SAMPLES)) begin
        $display("[TB][PASS] Reached %0d samples without align/data errors.", TARGET_SAMPLES);
        $finish;
      end
    end
  end

endmodule
