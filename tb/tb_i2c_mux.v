/*

Copyright (c) 2023 Tobias Binkowski <tobias.binkowski@missinglinkelectronics.com>

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

/* to run this testbench using Icarus run:
 * $ iverilog tb_i2c_mux.v i2c_master_model ../rtl/i2c_single_reg.v ../rtl/i2c_mux.v -o i2c_mux && ./i2c_mux
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module tb();

initial begin
    $dumpfile("i2c_mux.vcd");
    $dumpvars(0, tb);
end

localparam I2C_PERIOD = 1000000000 / 100000; // 1ns / 100kHz
localparam I2C_HPERIOD = I2C_PERIOD / 2;
localparam I2C_QPERIOD = I2C_PERIOD / 4;

reg clk = 0;
reg rst;
always #10 clk = ~clk;

// upstream i2c bus wires
wire io_scl, io_sda;

// downstream i2c bus wires
wire [3:0] s_scl, s_sda;

// testbench access to upstream i2c
wire i2c_model_sda, i2c_model_scl;

// iobuffer upstream
wire scl_i, scl_o, scl_t;
wire sda_i, sda_o, sda_t;
wire [3:0] s_scl_i, s_scl_o, s_scl_t;
wire [3:0] s_sda_i, s_sda_o, s_sda_t;

assign scl_i = (io_scl === 1'b0) ? 1'b0 : 1'b1;
assign io_scl = scl_t ? 1'bz : scl_o;
assign io_scl = i2c_model_scl ? 1'bz : 1'b0;
assign sda_i = (io_sda === 1'b0) ? 1'b0 : 1'b1;
assign io_sda = sda_t ? 1'bz : sda_o;
assign io_sda = i2c_model_sda ? 1'bz : 1'b0;

wire [3:0] selected_port;

reg [7:0] temp;
wire [7:0] reg1_data;

i2c_master_model #(
    .I2C_FREQUENCY(100000)
) i2c_master (
    .sda(io_sda), .sda_o(i2c_model_sda),
    .scl(io_scl), .scl_o(i2c_model_scl)
);

initial begin
    rst = 1'b1;
    #1000;
    rst = 1'b0;
    #1000;
    // check no port is selected after reset
    if (selected_port != 4'b0000)
        $error("selected_port is not zero after reset!");
    // select port index 0
    i2c_master.write(8'h70, 8'h04);
    if (selected_port != 4'b0001)
        $error("selected_port is not as expected");
    // readback mux register
    i2c_master.read(8'h70, temp);
    if (temp != 8'h04)
        $error("readback from mux does not match");
    // read connected register connected to selected port
    i2c_master.read(8'h42, temp);
    if (temp != 0)
        $error("read from address 0x42 at bus port 1 not matched expected value");
    // write to connected register
    i2c_master.write(8'h42, 8'hde);
    if (reg1_data != 8'hde)
        $error("write to connected slave failed");
    // read connected register connected to selected port
    i2c_master.read(8'h42, temp);
    if (temp != 8'hde)
        $error("read from address 0x42 at bus port 1 not matched expected value");
    i2c_master.write(8'h42, 8'h04);
    // select port index 1
    i2c_master.write(8'h70, 8'h05);
    if (selected_port != 4'b0010)
        $error("selected_port is not as expected");
    // try to read from now not available address
    i2c_master.read(8'h42, temp);
    if (temp != 8'hff)
        $error("read from non connected slave did not return 0xff");
    i2c_master.write(8'h70, 8'h06);
    if (selected_port != 4'b0100)
        $error("selected_port is not as expected");
    i2c_master.write(8'h70, 8'h07);
    if (selected_port != 4'b1000)
        $error("selected_port is not as expected");
    i2c_master.write(8'h70, 8'h00);
    if (selected_port != 4'b0000)
        $error("selected_port is not as expected");
    $finish;
end

i2c_mux i2c_mux_inst (
    .clk(clk),
    .rst(rst),
    .slave_scl_i(scl_i),
    .slave_scl_o(scl_o),
    .slave_scl_t(scl_t),
    .slave_sda_i(sda_i),
    .slave_sda_o(sda_o),
    .slave_sda_t(sda_t),
    .master_scl_i(s_scl_i),
    .master_scl_o(s_scl_o),
    .master_scl_t(s_scl_t),
    .master_sda_i(s_sda_i),
    .master_sda_o(s_sda_o),
    .master_sda_t(s_sda_t),
    .selected_port(selected_port)
);

// simple slave device on port 0
wire reg1_scl_i, reg1_scl_o, reg1_scl_t;
wire reg1_sda_i, reg1_sda_o, reg1_sda_t;

assign reg1_scl_i = s_scl_t[0] ? 1'b1 : s_scl_o[0];
assign s_scl_i[0] = reg1_scl_t ? 1'b1 : reg1_scl_o;
assign reg1_sda_i = s_sda_t[0] ? 1'b1 : s_sda_o[0];
assign s_sda_i[0] = reg1_sda_t ? 1'b1 : reg1_sda_o;

assign s_scl_i[1] = 1'b1;
assign s_scl_i[2] = 1'b1;
assign s_scl_i[3] = 1'b1;
assign s_sda_i[1] = 1'b1;
assign s_sda_i[2] = 1'b1;
assign s_sda_i[3] = 1'b1;

i2c_single_reg #(
    .FILTER_LEN(2),
    .DEV_ADDR(7'h42)
) i2c_single_reg_inst (
    .clk(clk),
    .rst(rst),
    .scl_i(reg1_scl_i),
    .scl_o(reg1_scl_o),
    .scl_t(reg1_scl_t),
    .sda_i(reg1_sda_i),
    .sda_o(reg1_sda_o),
    .sda_t(reg1_sda_t),
    .data_in(reg1_data),
    .data_latch(1'b0),
    .data_out(reg1_data)
);

endmodule

`resetall
