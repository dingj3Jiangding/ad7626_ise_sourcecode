`timescale 1ns/1ps

module ad7626_s6_serial_capture #(
  parameter integer SAMPLE_WIDTH      = 16,
  parameter integer BIT_COUNT_WIDTH   = 6,
  parameter integer DROP_FIRST_SAMPLE = 1,
  parameter         DIFF_TERM         = "TRUE"
) (
  input  wire                     sys_clk,
  input  wire                     rstn,
  input  wire                     dco_p,
  input  wire                     dco_n,
  input  wire                     d_p,
  input  wire                     d_n,
  output reg                      sample_valid,
  output reg  [SAMPLE_WIDTH-1:0]  sample_data,
  output wire                     dco_dbg,
  output wire                     data_dbg,

//timing debug singal 2026.4.16
  output wire [SAMPLE_WIDTH-1:0] sample_word_dco_dbg,
  output wire 							data_rise_dbg,
  output wire [BIT_COUNT_WIDTH-1:0] bit_count_dco_dbg,
  output wire [SAMPLE_WIDTH-1:0] shift_reg_dco_dbg
);

  wire                    dco_clk_s;
  wire                    data_s;
  wire                    data_rise_s;
  wire                    data_fall_unused_s;

  reg   [SAMPLE_WIDTH-1:0] shift_reg_dco;
  reg   [SAMPLE_WIDTH-1:0] sample_word_dco;
  reg   [BIT_COUNT_WIDTH-1:0] bit_count_dco;
  reg                      sample_toggle_dco;

  reg   [3:0]              sample_toggle_sync;
  reg   [SAMPLE_WIDTH-1:0] sample_word_meta;
  reg   [SAMPLE_WIDTH-1:0] sample_word_sync;
  reg                      drop_first_pending;
  
  assign data_rise_dbg = data_rise_s;
  assign shift_reg_dco_dbg = shift_reg_dco;
  assign bit_count_dco_dbg = bit_count_dco;

  IBUFGDS #(
    .DIFF_TERM(DIFF_TERM),
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("LVDS_25")
  ) i_dco_ibufds (
    .I (dco_p),
    .IB(dco_n),
    .O (dco_clk_s)
  );

  IBUFDS #(
    .DIFF_TERM(DIFF_TERM),
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("LVDS_25")
  ) i_data_ibufds (
    .I (d_p),
    .IB(d_n),
    .O (data_s)
  );

  assign dco_dbg  = dco_clk_s;
  assign data_dbg = data_s;


  IDDR2 #(
    .DDR_ALIGNMENT("C0"),
    .INIT_Q0(1'b0),
    .INIT_Q1(1'b0),
    .SRTYPE("SYNC")
  ) i_data_iddr2 (
    .Q0 (data_rise_s),              // Since data is changed at the falling edge of the dco, so it is more stable to sample the data at the rising edge.
    .Q1 (data_fall_unused_s),       // This signal is unused.
    .C0 (dco_clk_s),                // activated by rising edge
    .C1 (~dco_clk_s),               // also activated by rising edge, in this case, it is equal to the falling edge of dco
    .CE (1'b1),
    .D  (data_s),                   // data to be conveyed to Q0/Q1
    .R  (1'b0),
    .S  (1'b0)
  );


  // dco clock field, falling edge 
  always @(negedge dco_clk_s or negedge rstn) begin
    if (!rstn) begin
      shift_reg_dco      <= {SAMPLE_WIDTH{1'b0}};
      sample_word_dco    <= {SAMPLE_WIDTH{1'b0}};
      bit_count_dco      <= {BIT_COUNT_WIDTH{1'b0}};
      sample_toggle_dco  <= 1'b0;
    end else begin
      shift_reg_dco <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};

      if (bit_count_dco == (SAMPLE_WIDTH - 1)) begin
        sample_word_dco   <= {shift_reg_dco[SAMPLE_WIDTH-2:0], data_rise_s};    // due to the Characteristics of the <=, this is not shifting 2 times
        sample_toggle_dco <= ~sample_toggle_dco;
        bit_count_dco     <= {BIT_COUNT_WIDTH{1'b0}};
      end else begin
        bit_count_dco <= bit_count_dco + 1'b1;
      end
    end
  end

	assign sample_word_dco_dbg = sample_word_dco;
	
  // Cross Clock Domain transfer
  always @(posedge sys_clk or negedge rstn) begin
    if (!rstn) begin
      sample_valid       <= 1'b0;
      sample_data        <= {SAMPLE_WIDTH{1'b0}};
      sample_toggle_sync <= 4'b0000;
      sample_word_meta   <= {SAMPLE_WIDTH{1'b0}};
      sample_word_sync   <= {SAMPLE_WIDTH{1'b0}};
      drop_first_pending <= (DROP_FIRST_SAMPLE != 0);
    end else begin
      sample_valid       <= 1'b0;                       // 1 Clock-period Pulse
      sample_toggle_sync <= {sample_toggle_sync[2:0], sample_toggle_dco}; // using 4 layers(shifting bit) to store the toggle signal.
      sample_word_meta   <= sample_word_dco;            // meta means middle state
      sample_word_sync   <= sample_word_meta;

      if (sample_toggle_sync[3] ^ sample_toggle_sync[2]) begin    
      // FIFO, compare the toggle signals in the queue that are pushed first, 
      // to see if there is an edge. If so, then these is a sample valid. 
        if (drop_first_pending) begin
          drop_first_pending <= 1'b0;
        end else begin
          sample_valid <= 1'b1;
          sample_data  <= sample_word_sync;
        end
      end
    end
  end

endmodule
