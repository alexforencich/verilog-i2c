/*

Copyright (c) 2016-2017 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * Testbench for i2c_master_wbs_8
 */
module test_i2c_master_wbs_8;

  // Parameters
  parameter DEFAULT_PRESCALE = 1;
  parameter FIXED_PRESCALE = 0;
  parameter CMD_FIFO = 1;
  parameter CMD_FIFO_DEPTH = 32;
  parameter WRITE_FIFO = 1;
  parameter WRITE_FIFO_DEPTH = 32;
  parameter READ_FIFO = 1;
  parameter READ_FIFO_DEPTH = 32;

  // Inputs
  reg clk = 0;
  reg rst = 0;
  reg [7:0] current_test = 0;

  reg [2:0] wbs_adr_i = 0;
  reg [7:0] wbs_dat_i = 0;
  reg wbs_we_i = 0;
  reg wbs_stb_i = 0;
  reg wbs_cyc_i = 0;
  reg i2c_scl_i = 1;
  reg i2c_sda_i = 1;

  // Outputs
  wire [7:0] wbs_dat_o;
  wire wbs_ack_o;
  wire i2c_scl_o;
  wire i2c_scl_t;
  wire i2c_sda_o;
  wire i2c_sda_t;

  initial begin
    // myhdl integration
    $from_myhdl(clk, rst, current_test, wbs_adr_i, wbs_dat_i, wbs_we_i, wbs_stb_i, wbs_cyc_i,
                i2c_scl_i, i2c_sda_i);
    $to_myhdl(wbs_dat_o, wbs_ack_o, i2c_scl_o, i2c_scl_t, i2c_sda_o, i2c_sda_t);

    // dump file
    $dumpfile("test_i2c_master_wbs_8.lxt");
    $dumpvars(0, test_i2c_master_wbs_8);
  end

  i2c_master_wbs_8 #(
      .DEFAULT_PRESCALE(DEFAULT_PRESCALE),
      .FIXED_PRESCALE(FIXED_PRESCALE),
      .CMD_FIFO(CMD_FIFO),
      .CMD_FIFO_DEPTH(CMD_FIFO_DEPTH),
      .WRITE_FIFO(WRITE_FIFO),
      .WRITE_FIFO_DEPTH(WRITE_FIFO_DEPTH),
      .READ_FIFO(READ_FIFO),
      .READ_FIFO_DEPTH(READ_FIFO_DEPTH)
  ) UUT (
      .clk(clk),
      .rst(rst),
      .wbs_adr_i(wbs_adr_i),
      .wbs_dat_i(wbs_dat_i),
      .wbs_dat_o(wbs_dat_o),
      .wbs_we_i(wbs_we_i),
      .wbs_stb_i(wbs_stb_i),
      .wbs_ack_o(wbs_ack_o),
      .wbs_cyc_i(wbs_cyc_i),
      .i2c_scl_i(i2c_scl_i),
      .i2c_scl_o(i2c_scl_o),
      .i2c_scl_t(i2c_scl_t),
      .i2c_sda_i(i2c_sda_i),
      .i2c_sda_o(i2c_sda_o),
      .i2c_sda_t(i2c_sda_t)
  );

endmodule
