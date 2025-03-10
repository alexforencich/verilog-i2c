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
 * Testbench for i2c_slave_axil_master
 */
module test_i2c_slave_axil_master;

  // Parameters
  parameter FILTER_LEN = 4;
  parameter DATA_WIDTH = 32;
  parameter ADDR_WIDTH = 16;
  parameter STRB_WIDTH = (DATA_WIDTH / 8);

  // Inputs
  reg clk = 0;
  reg rst = 0;
  reg [7:0] current_test = 0;

  reg i2c_scl_i = 1;
  reg i2c_sda_i = 1;
  reg m_axil_awready = 0;
  reg m_axil_wready = 0;
  reg [1:0] m_axil_bresp = 0;
  reg m_axil_bvalid = 0;
  reg m_axil_arready = 0;
  reg [DATA_WIDTH-1:0] m_axil_rdata = 0;
  reg [1:0] m_axil_rresp = 0;
  reg m_axil_rvalid = 0;
  reg enable = 0;
  reg [6:0] device_address = 0;

  // Outputs
  wire i2c_scl_o;
  wire i2c_scl_t;
  wire i2c_sda_o;
  wire i2c_sda_t;
  wire [ADDR_WIDTH-1:0] m_axil_awaddr;
  wire [2:0] m_axil_awprot;
  wire m_axil_awvalid;
  wire [DATA_WIDTH-1:0] m_axil_wdata;
  wire [STRB_WIDTH-1:0] m_axil_wstrb;
  wire m_axil_wvalid;
  wire m_axil_bready;
  wire [ADDR_WIDTH-1:0] m_axil_araddr;
  wire [2:0] m_axil_arprot;
  wire m_axil_arvalid;
  wire m_axil_rready;
  wire busy;
  wire bus_addressed;
  wire bus_active;

  initial begin
    // myhdl integration
    $from_myhdl(clk, rst, current_test, i2c_scl_i, i2c_sda_i, m_axil_awready, m_axil_wready,
                m_axil_bresp, m_axil_bvalid, m_axil_arready, m_axil_rdata, m_axil_rresp,
                m_axil_rvalid, enable, device_address);
    $to_myhdl(i2c_scl_o, i2c_scl_t, i2c_sda_o, i2c_sda_t, m_axil_awaddr, m_axil_awprot,
              m_axil_awvalid, m_axil_wdata, m_axil_wstrb, m_axil_wvalid, m_axil_bready,
              m_axil_araddr, m_axil_arprot, m_axil_arvalid, m_axil_rready, busy, bus_addressed,
              bus_active);

    // dump file
    $dumpfile("test_i2c_slave_axil_master.lxt");
    $dumpvars(0, test_i2c_slave_axil_master);
  end

  i2c_slave_axil_master #(
      .FILTER_LEN(FILTER_LEN),
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH),
      .STRB_WIDTH(STRB_WIDTH)
  ) UUT (
      .clk(clk),
      .rst(rst),
      .i2c_scl_i(i2c_scl_i),
      .i2c_scl_o(i2c_scl_o),
      .i2c_scl_t(i2c_scl_t),
      .i2c_sda_i(i2c_sda_i),
      .i2c_sda_o(i2c_sda_o),
      .i2c_sda_t(i2c_sda_t),
      .m_axil_awaddr(m_axil_awaddr),
      .m_axil_awprot(m_axil_awprot),
      .m_axil_awvalid(m_axil_awvalid),
      .m_axil_awready(m_axil_awready),
      .m_axil_wdata(m_axil_wdata),
      .m_axil_wstrb(m_axil_wstrb),
      .m_axil_wvalid(m_axil_wvalid),
      .m_axil_wready(m_axil_wready),
      .m_axil_bresp(m_axil_bresp),
      .m_axil_bvalid(m_axil_bvalid),
      .m_axil_bready(m_axil_bready),
      .m_axil_araddr(m_axil_araddr),
      .m_axil_arprot(m_axil_arprot),
      .m_axil_arvalid(m_axil_arvalid),
      .m_axil_arready(m_axil_arready),
      .m_axil_rdata(m_axil_rdata),
      .m_axil_rresp(m_axil_rresp),
      .m_axil_rvalid(m_axil_rvalid),
      .m_axil_rready(m_axil_rready),
      .busy(busy),
      .bus_addressed(bus_addressed),
      .bus_active(bus_active),
      .enable(enable),
      .device_address(device_address)
  );

endmodule
