`timescale 1ns/100ps

module ad_data_in #(
  parameter   SINGLE_ENDED = 0,
  parameter   FPGA_TECHNOLOGY = 0,      // 保留接口兼容
  parameter   DDR_SDR_N = 1,
  parameter   IDDR_CLK_EDGE ="SAME_EDGE", // 保留接口兼容
  parameter   IDELAY_TYPE = "VAR_LOAD",   // 保留接口兼容
  parameter   DELAY_FORMAT = "COUNT",     // 保留接口兼容
  parameter   US_DELAY_TYPE = "VAR_LOAD", // 保留接口兼容
  parameter   IODELAY_ENABLE = 1,         // 保留接口兼容
  parameter   IODELAY_CTRL = 0,           // 保留接口兼容
  parameter   IODELAY_GROUP = "dev_if_delay_group", // 保留接口兼容
  parameter   REFCLK_FREQUENCY = 200      // 保留接口兼容
) (
  // data interface
  input               rx_clk,
  input               rx_data_in_p,
  input               rx_data_in_n,
  output              rx_data_p,
  output              rx_data_n,

  // delay-data interface
  input               up_clk,
  input               up_dld,
  input       [ 4:0]  up_dwdata,
  output      [ 4:0]  up_drdata,

  // delay-control interface
  input               delay_clk,
  input               delay_rst,
  output              delay_locked
);

  wire rx_data_ibuf_s;
  wire rx_data_idelay_s;

  // Spartan-6 最小实现：先旁路 delay 控制，后续再接 IODELAY2
  assign delay_locked   = 1'b1;
  assign up_drdata      = 5'd0;
  assign rx_data_idelay_s = rx_data_ibuf_s;

  // 输入缓冲
  generate
  if (SINGLE_ENDED == 1) begin
    IBUF i_rx_data_ibuf (
      .I (rx_data_in_p),
      .O (rx_data_ibuf_s)
    );
  end else begin
    IBUFDS i_rx_data_ibuf (
      .I  (rx_data_in_p),
      .IB (rx_data_in_n),
      .O  (rx_data_ibuf_s)
    );
  end
  endgenerate

  // DDR/SDR 采样
  generate
  if (DDR_SDR_N == 1'b1) begin
    IDDR2 #(
      .DDR_ALIGNMENT("C0"),
      .INIT_Q0(1'b0),
      .INIT_Q1(1'b0),
      .SRTYPE("SYNC")
    ) i_rx_data_iddr2 (
      .Q0 (rx_data_p),
      .Q1 (rx_data_n),
      .C0 (rx_clk),
      .C1 (~rx_clk),
      .CE (1'b1),
      .D  (rx_data_idelay_s),
      .R  (1'b0),
      .S  (1'b0)
    );
  end else begin
    assign rx_data_p = rx_data_idelay_s;
    assign rx_data_n = 1'b0;
  end
  endgenerate

endmodule