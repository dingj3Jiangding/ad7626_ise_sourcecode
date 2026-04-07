`timescale 1ns/100ps

module system_top_ise #(
  parameter CNV_PERIOD_CYCLES = 64,
  parameter CNV_HIGH_CYCLES = 8
) (
  input               ref_clk_p,
  input               ref_clk_n,

  input               dco_p,
  input               dco_n,
  input               d_p,
  input               d_n,

  output              clk_p,
  output              clk_n,
  output              cnv_p,
  output              cnv_n,

  output              en0_fmc,
  output              en1_fmc,
  output              en2_fmc,
  output              en3_fmc,

  // Debug outputs
  output              adc_valid,
  output      [17:0]  adc_data,

  // DMA-style streaming outputs
  output              dma_valid,
  output      [31:0]  dma_data
);

  // Internal clocks and control
  wire                ref_clk;
  reg   [15:0]        cnv_cnt = 16'd0;
  reg                 cnv = 1'b0;

  // Delay-control sideband is tied off in the Spartan-6 ad_data_in implementation.
  wire  [9:0]         up_drdata_unused;
  wire                delay_locked_unused;

  // Raw ADC samples from interface module.
  wire                adc_valid_raw;
  wire  [17:0]        adc_data_raw;

  // Buffer reference clock from FMC connector.
  ad_data_clk #(
    .SINGLE_ENDED(0)
  ) i_ref_clk (
    .rst(1'b0),
    .locked(),
    .clk_in_p(ref_clk_p),
    .clk_in_n(ref_clk_n),
    .clk(ref_clk)
  );

  // Generate CNV pulse with programmable period/high width.
  always @(posedge ref_clk) begin
    if (cnv_cnt == (CNV_PERIOD_CYCLES - 1)) begin
      cnv_cnt <= 16'd0;
    end else begin
      cnv_cnt <= cnv_cnt + 16'd1;
    end

    if (cnv_cnt < CNV_HIGH_CYCLES) begin
      cnv <= 1'b1;
    end else begin
      cnv <= 1'b0;
    end
  end

  // ADC interface (Spartan-6 compatible ad_data_in is used under axi_ad762x_if).
  axi_ad762x_if #(
    .FPGA_TECHNOLOGY(1),
    .IO_DELAY_GROUP("adc_if_delay_group"),
    .IODELAY_CTRL(0),
    .DELAY_REFCLK_FREQUENCY(200)
  ) i_adc_if (
    .up_clk(ref_clk),
    .up_dld(2'b00),
    .up_dwdata(10'd0),
    .up_drdata(up_drdata_unused),
    .delay_clk(ref_clk),
    .delay_rst(1'b0),
    .delay_locked(delay_locked_unused),
    .clk(ref_clk),
    .clk_gate(1'b1),
    .dco_p(dco_p),
    .dco_n(dco_n),
    .d_p(d_p),
    .d_n(d_n),
    .adc_valid(adc_valid_raw),
    .adc_data(adc_data_raw)
  );

  // LVDS outputs to ADC.
  OBUFDS i_clk_obuf (
    .I(ref_clk),
    .O(clk_p),
    .OB(clk_n)
  );

  OBUFDS i_cnv_obuf (
    .I(cnv),
    .O(cnv_p),
    .OB(cnv_n)
  );

  // Keep FMC enables asserted.
  assign en0_fmc = 1'b1;
  assign en1_fmc = 1'b1;
  assign en2_fmc = 1'b1;
  assign en3_fmc = 1'b1;

  // Export debug samples.
  assign adc_valid = adc_valid_raw;
  assign adc_data = adc_data_raw;

  // Simple 18-to-32-bit packing for downstream DMA logic.
  assign dma_valid = adc_valid_raw;
  assign dma_data = {14'd0, adc_data_raw};

endmodule
