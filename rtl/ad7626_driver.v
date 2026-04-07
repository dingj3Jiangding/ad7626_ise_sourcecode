`timescale 1ns/1ps


module ad7626_driver(
    // system rst

    output cnv_p,
    output cnv_n,

    output clk_p,
    output clk_n,

    input d_p,
    input d_n,

    input dco_p,
    input dco_n,

    output en0,
    output en1,

    output reg [15:0] data

   // More to add 
);

parameter t_cyc = 100   // 100-10000ns
parameter t_cnvh = 40   // ns
parameter t_msb = 100   // ns
parameter t_clkl = 72   // ns

IBUFDS #(
      .DIFF_TERM("FALSE"),       // Differential Termination
      .IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE" 
      .IOSTANDARD("LVDS_25")     // Specify the input I/O standard
   ) IBUFDS_D (
      .O(d),
      .I(d_p),
      .IB(d_n)
   );

//////// CLOCK INPUT //////

IBUFDS #(
      .DIFF_TERM("FALSE"),       // Differential Termination
      .IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE" 
      .IOSTANDARD("LVDS_25")     // Specify the input I/O standard
   ) IBUFDS_DCO (
      .O(dco_temp),
      .I(dco_p),
      .IB(dco_n)
   );

OBUFDS #(
      .IOSTANDARD("LVDS_25"), // Specify the output I/O standard
      .SLEW("SLOW")           // Specify the output slew rate
    ) OBUFDS_CNV (
      .O(cnv_p),     // Diff_p output (connect directly to top-level port)
      .OB(cnv_n),   // Diff_n output (connect directly to top-level port)
      .I(cnv)      // Buffer input
   );

OBUFDS #(
      .IOSTANDARD("LVDS_25"), // Specify the output I/O standard
      .SLEW("SLOW")           // Specify the output slew rate
    ) OBUFDS_CLK (
      .O(clk_p),     // Diff_p output (connect directly to top-level port)
      .OB(clk_n),   // Diff_n output (connect directly to top-level port)
      .I(clk)      // Buffer input
   );


endmodule
