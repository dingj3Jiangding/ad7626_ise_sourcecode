`timescale 1ns/1ps

module ad7626_day1_2_clkgen_100m_to_250m (
  input  wire clk_100_in,
  input  wire rstn,
  output wire clk_250_out,
  output wire locked
);

  wire clk_100_ibuf_s;
  wire clk_250_dcm_s;
  wire [7:0] status_unused_s;

  IBUFG i_sys_clk_100_ibufg (
    .I(clk_100_in),
    .O(clk_100_ibuf_s)
  );

  // Generate the 250 MHz fabric/read clock from the 100 MHz board oscillator.
  // 100 MHz * 5 / 2 = 250 MHz
  DCM_SP #(
    .CLK_FEEDBACK("NONE"),
    .CLKIN_DIVIDE_BY_2("FALSE"),
    .CLKIN_PERIOD(10.0),
    .CLKOUT_PHASE_SHIFT("NONE"),
    .CLKFX_DIVIDE(2),
    .CLKFX_MULTIPLY(5),
    .DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"),
    .DFS_FREQUENCY_MODE("HIGH"),
    .DLL_FREQUENCY_MODE("LOW"),
    .DUTY_CYCLE_CORRECTION("TRUE"),
    .PHASE_SHIFT(0),
    .STARTUP_WAIT("FALSE")
  ) i_sys_clk_dcm (
    .CLKIN(clk_100_ibuf_s),
    .CLKFB(1'b0),
    .RST(~rstn),
    .DSSEN(1'b0),
    .PSCLK(1'b0),
    .PSEN(1'b0),
    .PSINCDEC(1'b0),
    .CLK0(),
    .CLK90(),
    .CLK180(),
    .CLK270(),
    .CLK2X(),
    .CLK2X180(),
    .CLKDV(),
    .CLKFX(clk_250_dcm_s),
    .CLKFX180(),
    .LOCKED(locked),
    .PSDONE(),
    .STATUS(status_unused_s)
  );

  BUFG i_clk_250_bufg (
    .I(clk_250_dcm_s),
    .O(clk_250_out)
  );

endmodule
