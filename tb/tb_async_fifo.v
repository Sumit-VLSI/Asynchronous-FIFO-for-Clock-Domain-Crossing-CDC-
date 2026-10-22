

`timescale 1ns/1ps

module tb_async_fifo;
  parameter DEPTH = 8;
  parameter DATA_WIDTH = 8;

  reg wclk, rclk;
  reg wrst_n, rrst_n;
  reg w_en, r_en;
  reg [DATA_WIDTH-1:0] data_in;
  wire [DATA_WIDTH-1:0] data_out;
  wire full, empty;

  // DUT instantiation
  asynchronous_fifo #(DEPTH, DATA_WIDTH) dut (
    .wclk(wclk), .wrst_n(wrst_n),
    .rclk(rclk), .rrst_n(rrst_n),
    .w_en(w_en), .r_en(r_en),
    .data_in(data_in),
    .data_out(data_out),
    .full(full), .empty(empty)
  );

  // Clock generation
  initial begin
    wclk = 0;
    forever #5 wclk = ~wclk;   // 100 MHz write clock
  end

  initial begin
    rclk = 0;
    forever #7 rclk = ~rclk;   // ~71 MHz read clock
  end

  // Stimulus
  integer i;
  reg [DATA_WIDTH-1:0] expected_mem[0:DEPTH-1];
  integer wcount = 0;
  integer rcount = 0;

  initial begin
    // Reset
    wrst_n = 0; rrst_n = 0;
    w_en = 0; r_en = 0; data_in = 0;
    #20;
    wrst_n = 1; rrst_n = 1;

    // Write 8 values into FIFO
    @(posedge wclk);
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge wclk);
      if (!full) begin
        w_en <= 1;
        data_in <= i + 8'hA0;   // pattern: A0, A1, A2...
        expected_mem[wcount] = i + 8'hA0;
        wcount = wcount + 1;
      end else begin
        w_en <= 0;
      end
    end
    w_en <= 0;

   
    // Read back values
   for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge rclk);
      while (empty) @(posedge rclk);
      
      r_en <= 1;
      
      @(posedge rclk); // Wait for the DUT to process the read
      r_en <= 0;
      
      #1; // Add a 1ns propagation delay so data_out updates before printing
      
      $display("Read[%0d] = %h, Expected = %h %s",
               rcount, data_out, expected_mem[rcount],
               (data_out == expected_mem[rcount]) ? "PASS" : "FAIL");
      rcount = rcount + 1;
    end
    #50;
    $finish;
  end
endmodule
