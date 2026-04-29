`timescale 1ns/1ps

module ad7626_double_buffer #(
  parameter integer SAMPLE_WIDTH      = 16,
  parameter integer HALF_BUFFER_DEPTH = 4096,
  parameter integer ADDR_WIDTH        = 12
) (
  input  wire                         clk,
  input  wire                         rstn,
  input  wire                         capture_enable,
  input  wire                         soft_reset,
  input  wire                         sample_valid,
  input  wire [SAMPLE_WIDTH-1:0]      sample_data,
  input  wire                         ack_buf0,
  input  wire                         ack_buf1,

  input  wire [ADDR_WIDTH-1:0]        buf0_raddr,
  input  wire [ADDR_WIDTH-1:0]        buf1_raddr,
  output reg  [SAMPLE_WIDTH-1:0]      buf0_rdata,
  output reg  [SAMPLE_WIDTH-1:0]      buf1_rdata,

  output reg                          buf0_ready,
  output reg                          buf1_ready,
  output reg                          active_buf,
  output reg                          overrun,
  output reg  [ADDR_WIDTH:0]          half_word_count
);

  reg [SAMPLE_WIDTH-1:0] buf0_mem [0:HALF_BUFFER_DEPTH-1];
  reg [SAMPLE_WIDTH-1:0] buf1_mem [0:HALF_BUFFER_DEPTH-1];

  reg                    buf0_free;
  reg                    buf1_free;
  reg [ADDR_WIDTH:0]     write_index;

  initial begin
    if (HALF_BUFFER_DEPTH <= 0) begin
      $display("[DOUBLE_BUFFER][WARN] HALF_BUFFER_DEPTH should be greater than 0.");
    end

    if ((1 << ADDR_WIDTH) < HALF_BUFFER_DEPTH) begin
      $display("[DOUBLE_BUFFER][WARN] ADDR_WIDTH=%0d is too small for HALF_BUFFER_DEPTH=%0d.",
               ADDR_WIDTH, HALF_BUFFER_DEPTH);
    end
  end

  always @(posedge clk) begin
    buf0_rdata <= buf0_mem[buf0_raddr];
    buf1_rdata <= buf1_mem[buf1_raddr];
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      buf0_ready       <= 1'b0;
      buf1_ready       <= 1'b0;
      buf0_free        <= 1'b1;
      buf1_free        <= 1'b1;
      active_buf       <= 1'b0;
      overrun          <= 1'b0;
      half_word_count  <= {(ADDR_WIDTH + 1){1'b0}};       // index 0-4095 [12bit], number max 4096 [13bit]
      write_index      <= {(ADDR_WIDTH + 1){1'b0}};
    end else begin
      if (soft_reset) begin
        buf0_ready       <= 1'b0;
        buf1_ready       <= 1'b0;
        buf0_free        <= 1'b1;
        buf1_free        <= 1'b1;
        active_buf       <= 1'b0;
        overrun          <= 1'b0;
        half_word_count  <= {(ADDR_WIDTH + 1){1'b0}};
        write_index      <= {(ADDR_WIDTH + 1){1'b0}};
      end else begin
        if (ack_buf0) begin       // when receive acknowledge signal, the buffer value is not ready to be read.
                                  // also the buffer is free to be written
          buf0_ready <= 1'b0;
          buf0_free  <= 1'b1;
        end

        if (ack_buf1) begin
          buf1_ready <= 1'b0;
          buf1_free  <= 1'b1;
        end

        if (capture_enable && sample_valid) begin
          if (active_buf == 1'b0) begin
            if (buf0_free || ack_buf0) begin
              buf0_mem[write_index[ADDR_WIDTH-1:0]] <= sample_data;

              if (write_index == (HALF_BUFFER_DEPTH - 1)) begin
                buf0_ready      <= 1'b1;
                buf0_free       <= 1'b0;
                half_word_count <= HALF_BUFFER_DEPTH[ADDR_WIDTH:0];
                write_index     <= {(ADDR_WIDTH + 1){1'b0}};
                // Advance ownership to the other half immediately. If it is
                // still busy, the next sample will raise overrun.
                active_buf      <= 1'b1;
              end else begin
                write_index     <= write_index + 1'b1;
                half_word_count <= write_index + 1'b1;
              end
            end else begin
              overrun <= 1'b1;
            end
          end else begin
            if (buf1_free || ack_buf1) begin
              buf1_mem[write_index[ADDR_WIDTH-1:0]] <= sample_data;

              if (write_index == (HALF_BUFFER_DEPTH - 1)) begin
                buf1_ready      <= 1'b1;
                buf1_free       <= 1'b0;
                half_word_count <= HALF_BUFFER_DEPTH[ADDR_WIDTH:0];
                write_index     <= {(ADDR_WIDTH + 1){1'b0}};
                active_buf      <= 1'b0;
              end else begin
                write_index     <= write_index + 1'b1;
                half_word_count <= write_index + 1'b1;
              end
            end else begin
              overrun <= 1'b1;
            end
          end
        end else begin              // this branch means there is no sample point to be written [capture_enable == 0 or sample_valid == 0]
          if (capture_enable && ((active_buf == 1'b0) ? buf0_free : buf1_free)) begin     // when capture_enable == 1, half_word_count still means the many sample written
            half_word_count <= write_index;                                               // this part is for rubustness, actually the value of half_word_count will remain this value.
          end
        end
      end
    end
  end

endmodule
