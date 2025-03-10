/*

Copyright (c) 2015-2017 Alex Forencich

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
 * Testbench for i2c_init
 */
module test_i2c_init;

  // Parameters

  // Inputs
  reg clk = 0;
  reg rst = 0;
  reg [7:0] current_test = 0;

  reg m_axis_cmd_ready = 0;
  reg m_axis_data_tready = 0;
  reg start = 0;

  // Outputs
  wire [6:0] m_axis_cmd_address;
  wire m_axis_cmd_start;
  wire m_axis_cmd_read;
  wire m_axis_cmd_write;
  wire m_axis_cmd_write_multiple;
  wire m_axis_cmd_stop;
  wire m_axis_cmd_valid;
  wire [7:0] m_axis_data_tdata;
  wire m_axis_data_tvalid;
  wire m_axis_data_tlast;
  wire busy;

  initial begin
    // myhdl integration
    $from_myhdl(clk, rst, current_test, m_axis_cmd_ready, m_axis_data_tready, start);
    $to_myhdl(m_axis_cmd_address, m_axis_cmd_start, m_axis_cmd_read, m_axis_cmd_write,
              m_axis_cmd_write_multiple, m_axis_cmd_stop, m_axis_cmd_valid, m_axis_data_tdata,
              m_axis_data_tvalid, m_axis_data_tlast, busy);

    // dump file
    $dumpfile("test_i2c_init.lxt");
    $dumpvars(0, test_i2c_init);
  end

  i2c_init UUT (
      .clk(clk),
      .rst(rst),
      .m_axis_cmd_address(m_axis_cmd_address),
      .m_axis_cmd_start(m_axis_cmd_start),
      .m_axis_cmd_read(m_axis_cmd_read),
      .m_axis_cmd_write(m_axis_cmd_write),
      .m_axis_cmd_write_multiple(m_axis_cmd_write_multiple),
      .m_axis_cmd_stop(m_axis_cmd_stop),
      .m_axis_cmd_valid(m_axis_cmd_valid),
      .m_axis_cmd_ready(m_axis_cmd_ready),
      .m_axis_data_tdata(m_axis_data_tdata),
      .m_axis_data_tvalid(m_axis_data_tvalid),
      .m_axis_data_tready(m_axis_data_tready),
      .m_axis_data_tlast(m_axis_data_tlast),
      .busy(busy),
      .start(start)
  );

endmodule
