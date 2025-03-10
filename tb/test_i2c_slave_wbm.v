/*

Copyright (c) 2017 Alex Forencich

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
 * Testbench for i2c_slave_wbm
 */
module test_i2c_slave_wbm;

  // Parameters
  parameter FILTER_LEN = 4;
  parameter WB_DATA_WIDTH = 32;
  parameter WB_ADDR_WIDTH = 16;
  parameter WB_SELECT_WIDTH = WB_DATA_WIDTH / 8;

  // Inputs
  reg clk = 0;
  reg rst = 0;
  reg [7:0] current_test = 0;

  reg i2c_scl_i = 1;
  reg i2c_sda_i = 1;
  reg [WB_DATA_WIDTH-1:0] wb_dat_i = 0;
  reg wb_ack_i = 0;
  reg wb_err_i = 0;
  reg enable = 0;
  reg [6:0] device_address = 0;

  // Outputs
  wire i2c_scl_o;
  wire i2c_scl_t;
  wire i2c_sda_o;
  wire i2c_sda_t;
  wire [WB_ADDR_WIDTH-1:0] wb_adr_o;
  wire [WB_DATA_WIDTH-1:0] wb_dat_o;
  wire wb_we_o;
  wire [WB_SELECT_WIDTH-1:0] wb_sel_o;
  wire wb_stb_o;
  wire wb_cyc_o;
  wire busy;
  wire bus_addressed;
  wire bus_active;

  initial begin
    // myhdl integration
    $from_myhdl(clk, rst, current_test, i2c_scl_i, i2c_sda_i, wb_dat_i, wb_ack_i, wb_err_i, enable,
                device_address);
    $to_myhdl(i2c_scl_o, i2c_scl_t, i2c_sda_o, i2c_sda_t, wb_adr_o, wb_dat_o, wb_we_o, wb_sel_o,
              wb_stb_o, wb_cyc_o, busy, bus_addressed, bus_active);

    // dump file
    $dumpfile("test_i2c_slave_wbm.lxt");
    $dumpvars(0, test_i2c_slave_wbm);
  end

  i2c_slave_wbm #(
      .FILTER_LEN(FILTER_LEN),
      .WB_DATA_WIDTH(WB_DATA_WIDTH),
      .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
      .WB_SELECT_WIDTH(WB_SELECT_WIDTH)
  ) UUT (
      .clk(clk),
      .rst(rst),
      .i2c_scl_i(i2c_scl_i),
      .i2c_scl_o(i2c_scl_o),
      .i2c_scl_t(i2c_scl_t),
      .i2c_sda_i(i2c_sda_i),
      .i2c_sda_o(i2c_sda_o),
      .i2c_sda_t(i2c_sda_t),
      .wb_adr_o(wb_adr_o),
      .wb_dat_i(wb_dat_i),
      .wb_dat_o(wb_dat_o),
      .wb_we_o(wb_we_o),
      .wb_sel_o(wb_sel_o),
      .wb_stb_o(wb_stb_o),
      .wb_ack_i(wb_ack_i),
      .wb_err_i(wb_err_i),
      .wb_cyc_o(wb_cyc_o),
      .busy(busy),
      .bus_addressed(bus_addressed),
      .bus_active(bus_active),
      .enable(enable),
      .device_address(device_address)
  );

endmodule
