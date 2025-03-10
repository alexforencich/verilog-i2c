/*

Copyright (c) 2019 Alex Forencich

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
 * Testbench for i2c_master_axil
 */
module test_i2c_master_axil;

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

  reg [3:0] s_axil_awaddr = 0;
  reg [2:0] s_axil_awprot = 0;
  reg s_axil_awvalid = 0;
  reg [31:0] s_axil_wdata = 0;
  reg [3:0] s_axil_wstrb = 0;
  reg s_axil_wvalid = 0;
  reg s_axil_bready = 0;
  reg [3:0] s_axil_araddr = 0;
  reg [2:0] s_axil_arprot = 0;
  reg s_axil_arvalid = 0;
  reg s_axil_rready = 0;
  reg i2c_scl_i = 1;
  reg i2c_sda_i = 1;

  // Outputs
  wire s_axil_awready;
  wire s_axil_wready;
  wire [1:0] s_axil_bresp;
  wire s_axil_bvalid;
  wire s_axil_arready;
  wire [31:0] s_axil_rdata;
  wire [1:0] s_axil_rresp;
  wire s_axil_rvalid;
  wire i2c_scl_o;
  wire i2c_scl_t;
  wire i2c_sda_o;
  wire i2c_sda_t;

  initial begin
    // myhdl integration
    $from_myhdl(clk, rst, current_test, s_axil_awaddr, s_axil_awprot, s_axil_awvalid, s_axil_wdata,
                s_axil_wstrb, s_axil_wvalid, s_axil_bready, s_axil_araddr, s_axil_arprot,
                s_axil_arvalid, s_axil_rready, i2c_scl_i, i2c_sda_i);
    $to_myhdl(s_axil_awready, s_axil_wready, s_axil_bresp, s_axil_bvalid, s_axil_arready,
              s_axil_rdata, s_axil_rresp, s_axil_rvalid, i2c_scl_o, i2c_scl_t, i2c_sda_o,
              i2c_sda_t);

    // dump file
    $dumpfile("test_i2c_master_axil.lxt");
    $dumpvars(0, test_i2c_master_axil);
  end

  i2c_master_axil #(
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
      .s_axil_awaddr(s_axil_awaddr),
      .s_axil_awprot(s_axil_awprot),
      .s_axil_awvalid(s_axil_awvalid),
      .s_axil_awready(s_axil_awready),
      .s_axil_wdata(s_axil_wdata),
      .s_axil_wstrb(s_axil_wstrb),
      .s_axil_wvalid(s_axil_wvalid),
      .s_axil_wready(s_axil_wready),
      .s_axil_bresp(s_axil_bresp),
      .s_axil_bvalid(s_axil_bvalid),
      .s_axil_bready(s_axil_bready),
      .s_axil_araddr(s_axil_araddr),
      .s_axil_arprot(s_axil_arprot),
      .s_axil_arvalid(s_axil_arvalid),
      .s_axil_arready(s_axil_arready),
      .s_axil_rdata(s_axil_rdata),
      .s_axil_rresp(s_axil_rresp),
      .s_axil_rvalid(s_axil_rvalid),
      .s_axil_rready(s_axil_rready),
      .i2c_scl_i(i2c_scl_i),
      .i2c_scl_o(i2c_scl_o),
      .i2c_scl_t(i2c_scl_t),
      .i2c_sda_i(i2c_sda_i),
      .i2c_sda_o(i2c_sda_o),
      .i2c_sda_t(i2c_sda_t)
  );

endmodule
