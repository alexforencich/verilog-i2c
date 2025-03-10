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
 * Testbench for i2c_slave
 */
module test_i2c_slave;

  // Parameters
  parameter FILTER_LEN = 2;

  // Inputs
  reg clk = 0;
  reg rst = 0;
  reg [7:0] current_test = 0;

  reg release_bus = 0;
  reg [7:0] s_axis_data_tdata = 0;
  reg s_axis_data_tvalid = 0;
  reg s_axis_data_tlast = 0;
  reg m_axis_data_tready = 0;
  reg scl_i = 1;
  reg sda_i = 1;
  reg enable = 0;
  reg [6:0] device_address = 0;
  reg [6:0] device_address_mask = 0;

  // Outputs
  wire s_axis_data_tready;
  wire [7:0] m_axis_data_tdata;
  wire m_axis_data_tvalid;
  wire m_axis_data_tlast;
  wire scl_o;
  wire scl_t;
  wire sda_o;
  wire sda_t;
  wire busy;
  wire [6:0] bus_address;
  wire bus_addressed;
  wire bus_active;

  initial begin
    // myhdl integration
    $from_myhdl(clk, rst, current_test, release_bus, s_axis_data_tdata, s_axis_data_tvalid,
                s_axis_data_tlast, m_axis_data_tready, scl_i, sda_i, enable, device_address,
                device_address_mask);
    $to_myhdl(s_axis_data_tready, m_axis_data_tdata, m_axis_data_tvalid, m_axis_data_tlast, scl_o,
              scl_t, sda_o, sda_t, busy, bus_address, bus_addressed, bus_active);

    // dump file
    $dumpfile("test_i2c_slave.lxt");
    $dumpvars(0, test_i2c_slave);
  end

  i2c_slave #(
      .FILTER_LEN(FILTER_LEN)
  ) UUT (
      .clk(clk),
      .rst(rst),
      .release_bus(release_bus),
      .s_axis_data_tdata(s_axis_data_tdata),
      .s_axis_data_tvalid(s_axis_data_tvalid),
      .s_axis_data_tready(s_axis_data_tready),
      .s_axis_data_tlast(s_axis_data_tlast),
      .m_axis_data_tdata(m_axis_data_tdata),
      .m_axis_data_tvalid(m_axis_data_tvalid),
      .m_axis_data_tready(m_axis_data_tready),
      .m_axis_data_tlast(m_axis_data_tlast),
      .scl_i(scl_i),
      .scl_o(scl_o),
      .scl_t(scl_t),
      .sda_i(sda_i),
      .sda_o(sda_o),
      .sda_t(sda_t),
      .busy(busy),
      .bus_address(bus_address),
      .bus_addressed(bus_addressed),
      .bus_active(bus_active),
      .enable(enable),
      .device_address(device_address),
      .device_address_mask(device_address_mask)
  );

endmodule
