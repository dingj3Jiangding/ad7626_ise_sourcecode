`timescale 1ns/1ps

module tb_ad7626_double_buffer;

  localparam integer SAMPLE_WIDTH      = 16;
  localparam integer HALF_BUFFER_DEPTH = 8;
  localparam integer ADDR_WIDTH        = 3;

  reg                         clk;
  reg                         rstn;
  reg                         capture_enable;
  reg                         soft_reset;
  reg                         sample_valid;
  reg  [SAMPLE_WIDTH-1:0]     sample_data;
  reg                         ack_buf0;
  reg                         ack_buf1;
  reg  [ADDR_WIDTH-1:0]       buf0_raddr;
  reg  [ADDR_WIDTH-1:0]       buf1_raddr;

  wire [SAMPLE_WIDTH-1:0]     buf0_rdata;
  wire [SAMPLE_WIDTH-1:0]     buf1_rdata;
  wire                        buf0_ready;
  wire                        buf1_ready;
  wire                        active_buf;
  wire                        overrun;
  wire [ADDR_WIDTH:0]         half_word_count;

  integer                     i;

  ad7626_double_buffer #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .HALF_BUFFER_DEPTH(HALF_BUFFER_DEPTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) dut (
    .clk(clk),
    .rstn(rstn),
    .capture_enable(capture_enable),
    .soft_reset(soft_reset),
    .sample_valid(sample_valid),
    .sample_data(sample_data),
    .ack_buf0(ack_buf0),
    .ack_buf1(ack_buf1),
    .buf0_raddr(buf0_raddr),
    .buf1_raddr(buf1_raddr),
    .buf0_rdata(buf0_rdata),
    .buf1_rdata(buf1_rdata),
    .buf0_ready(buf0_ready),
    .buf1_ready(buf1_ready),
    .active_buf(active_buf),
    .overrun(overrun),
    .half_word_count(half_word_count)
  );

  // Drive stimuli on negedge so the DUT sees stable inputs on posedge.
  task send_sample;
    input [SAMPLE_WIDTH-1:0] value;
    begin
      @(negedge clk);
      sample_valid = 1'b1;
      sample_data  = value;
      @(posedge clk);
      @(negedge clk);
      sample_valid = 1'b0;
      sample_data  = {SAMPLE_WIDTH{1'b0}};
    end
  endtask

  task pulse_ack0;
    begin
      @(negedge clk);
      ack_buf0 = 1'b1;
      @(posedge clk);
      @(negedge clk);
      ack_buf0 = 1'b0;
    end
  endtask

  task pulse_ack1;
    begin
      @(negedge clk);
      ack_buf1 = 1'b1;
      @(posedge clk);
      @(negedge clk);
      ack_buf1 = 1'b0;
    end
  endtask

  task check_buf0_value;
    input integer addr;
    input [SAMPLE_WIDTH-1:0] expected;
    begin
      @(negedge clk);
      buf0_raddr = addr[ADDR_WIDTH-1:0];
      @(posedge clk);
      @(negedge clk);
      if (buf0_rdata !== expected) begin
        $display("[TB_DOUBLE_BUFFER][FAIL] BUF0[%0d] = 0x%0h expected 0x%0h",
                 addr, buf0_rdata, expected);
        $finish;
      end
    end
  endtask

  task check_buf1_value;
    input integer addr;
    input [SAMPLE_WIDTH-1:0] expected;
    begin
      @(negedge clk);
      buf1_raddr = addr[ADDR_WIDTH-1:0];
      @(posedge clk);
      @(negedge clk);
      if (buf1_rdata !== expected) begin
        $display("[TB_DOUBLE_BUFFER][FAIL] BUF1[%0d] = 0x%0h expected 0x%0h",
                 addr, buf1_rdata, expected);
        $finish;
      end
    end
  endtask

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rstn           = 1'b0;
    capture_enable = 1'b0;
    soft_reset     = 1'b0;
    sample_valid   = 1'b0;
    sample_data    = {SAMPLE_WIDTH{1'b0}};
    ack_buf0       = 1'b0;
    ack_buf1       = 1'b0;
    buf0_raddr     = {ADDR_WIDTH{1'b0}};
    buf1_raddr     = {ADDR_WIDTH{1'b0}};

    repeat (4) @(posedge clk);
    rstn <= 1'b1;
  end

  initial begin
`ifdef VCD_DUMP
    $dumpfile("tb_ad7626_double_buffer.vcd");
    $dumpvars(0, tb_ad7626_double_buffer);
`endif
  end

  initial begin
    @(posedge rstn);
    @(posedge clk);

    capture_enable <= 1'b1;

    for (i = 0; i < HALF_BUFFER_DEPTH; i = i + 1) begin
      send_sample(16'h1000 + i[15:0]);
    end

    if (!buf0_ready) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] BUF0 should be ready after first fill.");
      $finish;
    end

    if (active_buf !== 1'b1) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] active_buf should switch to BUF1 after BUF0 fills.");
      $finish;
    end

    if (half_word_count !== HALF_BUFFER_DEPTH[ADDR_WIDTH:0]) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] half_word_count should report full depth after BUF0 fill.");
      $finish;
    end

    check_buf0_value(0, 16'h1000);
    check_buf0_value(3, 16'h1003);
    check_buf0_value(7, 16'h1007);

    for (i = 0; i < HALF_BUFFER_DEPTH; i = i + 1) begin
      send_sample(16'h2000 + i[15:0]);
    end

    if (!buf1_ready) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] BUF1 should be ready after second fill.");
      $finish;
    end

    if (overrun) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] overrun should still be low immediately after filling BUF1.");
      $finish;
    end

    check_buf1_value(0, 16'h2000);
    check_buf1_value(4, 16'h2004);
    check_buf1_value(7, 16'h2007);

    send_sample(16'h3000);

    if (!overrun) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] overrun should assert when both halves are unavailable.");
      $finish;
    end

    pulse_ack0();

    if (buf0_ready) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] BUF0 ready should clear after ACK0.");
      $finish;
    end

    if (buf1_ready !== 1'b1) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] BUF1 ready should remain set after ACK0.");
      $finish;
    end

    pulse_ack1();

    if (buf1_ready) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] BUF1 ready should clear after ACK1.");
      $finish;
    end

    soft_reset <= 1'b1;
    @(posedge clk);
    soft_reset <= 1'b0;
    @(posedge clk);

    if (buf0_ready || buf1_ready || overrun || (active_buf !== 1'b0) || (half_word_count !== 0)) begin
      $display("[TB_DOUBLE_BUFFER][FAIL] soft_reset did not restore the expected idle state.");
      $finish;
    end

    $display("[TB_DOUBLE_BUFFER][PASS] fill/switch/ack/overrun/readback behavior verified.");
    $finish;
  end

  initial begin
    repeat (400) @(posedge clk);
    $display("[TB_DOUBLE_BUFFER][FAIL] Timeout.");
    $finish;
  end

endmodule
