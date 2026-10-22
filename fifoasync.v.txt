`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Sumit
// 
// Create Date: 03.02.2026
// Design Name: Asynchronous FIFO
// Description: 
// 
//////////////////////////////////////////////////////////////////////////////////
// -------------------- Top-Level Asynchronous FIFO --------------------
module asynchronous_fifo #(parameter DEPTH=8, DATA_WIDTH=8) (
  input wclk, wrst_n,
  input rclk, rrst_n,
  input w_en, r_en,
  input [DATA_WIDTH-1:0] data_in,
  output wire [DATA_WIDTH-1:0] data_out,
  output wire full, empty
);
  parameter PTR_WIDTH = $clog2(DEPTH);

  wire [PTR_WIDTH:0] g_wptr_sync, g_rptr_sync;
  wire [PTR_WIDTH:0] b_wptr, b_rptr;
  wire [PTR_WIDTH:0] g_wptr, g_rptr;

  // Synchronizers
  synchronizer #(PTR_WIDTH) sync_wptr (rclk, rrst_n, g_wptr, g_wptr_sync);
  synchronizer #(PTR_WIDTH) sync_rptr (wclk, wrst_n, g_rptr, g_rptr_sync);

  // Pointer Handlers
  wptr_handler #(PTR_WIDTH) wptr_h(wclk, wrst_n, w_en, g_rptr_sync,
                                   b_wptr, g_wptr, full);
  rptr_handler #(PTR_WIDTH) rptr_h(rclk, rrst_n, r_en, g_wptr_sync,
                                   b_rptr, g_rptr, empty);

  // FIFO Memory
  fifo_mem #(DEPTH, DATA_WIDTH, PTR_WIDTH) fifom(wclk, w_en, rclk, r_en,
                                                 b_wptr, b_rptr,
                                                 data_in, full, empty,
                                                 data_out);
endmodule
// -------------------- Write Pointer Handler --------------------
module wptr_handler #(parameter PTR_WIDTH=3) (
  input wclk, wrst_n, w_en,
  input [PTR_WIDTH:0] g_rptr_sync,
  output reg [PTR_WIDTH:0] b_wptr, g_wptr,
  output reg full
);
  wire [PTR_WIDTH:0] b_wptr_next;
  wire [PTR_WIDTH:0] g_wptr_next;
  wire wfull;

  assign b_wptr_next = b_wptr + (w_en & !full);
  
  assign g_wptr_next = (b_wptr_next >> 1) ^ b_wptr_next; // binary → gray

  always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n)
     begin
      b_wptr <= 0;
      g_wptr <= 0;
    end
     else
      begin
      b_wptr <= b_wptr_next;
      g_wptr <= g_wptr_next;
    end
  end

  always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) 
      full <= 0;
    else 
       full <= wfull;
  end

  // Full condition: next write pointer == read pointer with MSBs inverted
  assign wfull = (g_wptr_next == {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1],
                                  g_rptr_sync[PTR_WIDTH-2:0]});
                                  
endmodule

// -------------------- Read Pointer Handler --------------------
module rptr_handler #(parameter PTR_WIDTH=3) (
  input rclk, rrst_n, r_en,
  input [PTR_WIDTH:0] g_wptr_sync,
  output reg [PTR_WIDTH:0] b_rptr, g_rptr,
  output reg empty
);
  wire [PTR_WIDTH:0] b_rptr_next;
  wire [PTR_WIDTH:0] g_rptr_next;
  wire rempty;

  assign b_rptr_next = b_rptr + (r_en & !empty);
  assign g_rptr_next = (b_rptr_next >> 1) ^ b_rptr_next;
  assign rempty = (g_wptr_sync == g_rptr_next);

  always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n)
     begin
      b_rptr <= 0;
      g_rptr <= 0;
    end 
    else
     begin
      b_rptr <= b_rptr_next;
      g_rptr <= g_rptr_next;
    end
  end

  always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) 
      empty <= 1;
    else  
       empty <= rempty;
  end
endmodule

// -------------------- Synchronizer --------------------
module synchronizer #(parameter WIDTH=3) (
  input clk, rst_n,
  input [WIDTH:0] d_in,
  output reg [WIDTH:0] d_out
);
  reg [WIDTH:0] q1;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
     begin
      q1 <= 0;
      d_out <= 0;
    end
     else
      begin
      q1 <= d_in;
      d_out <= q1;
    end
  end
endmodule

// -------------------- FIFO Memory --------------------
module fifo_mem #(parameter DEPTH=8, DATA_WIDTH=8, PTR_WIDTH=3) (
  input wclk, w_en, rclk, r_en,
  input [PTR_WIDTH:0] b_wptr, b_rptr,
  input [DATA_WIDTH-1:0] data_in,
  input full, empty,
  output reg [DATA_WIDTH-1:0] data_out
);
  reg [DATA_WIDTH-1:0] fifo[0:DEPTH-1];

  always @(posedge wclk) begin
    if (w_en & !full) begin
      fifo[b_wptr[PTR_WIDTH-1:0]] <= data_in;
    end
  end

  always @(posedge rclk) begin
    if (r_en & !empty) begin
      data_out <= fifo[b_rptr[PTR_WIDTH-1:0]];
    end
  end
endmodule

