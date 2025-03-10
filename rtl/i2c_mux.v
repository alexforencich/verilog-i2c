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

`resetall
`timescale 1ns / 1ps
`default_nettype none

/* A simple i2c mux implementing a compatible register access as the TCA9544A */

module i2c_mux #(
    parameter FILTER_LEN = 4,
    parameter RISE_LEN = 8,
    parameter DEV_ADDR = 7'h70,
    parameter PORTS = 4
)
(
    input wire        clk,
    input wire        rst,
    output wire [PORTS-1:0] selected_port,

    /*
     * I2C slave interface
     */
    input  wire       slave_scl_i,
    output wire       slave_scl_o,
    output wire       slave_scl_t,
    input  wire       slave_sda_i,
    output wire       slave_sda_o,
    output wire       slave_sda_t,

    /*
     * I2C master interfaces
     */
    input  wire [PORTS-1:0] master_scl_i,
    output wire [PORTS-1:0] master_scl_o,
    output wire [PORTS-1:0] master_scl_t,
    input  wire [PORTS-1:0] master_sda_i,
    output wire [PORTS-1:0] master_sda_o,
    output wire [PORTS-1:0] master_sda_t
);

wire [7:0] mux_reg;
wire mux_scl_o;
wire mux_scl_t;
wire mux_sda_o;
wire mux_sda_t;

i2c_single_reg #(
    .FILTER_LEN(FILTER_LEN),
    .DEV_ADDR(DEV_ADDR)
) i2c_single_reg_inst (
    .clk(clk),
    .rst(rst),
    .scl_i(slave_scl_i),
    .scl_o(mux_scl_o),
    .scl_t(mux_scl_t),
    .sda_i(slave_sda_i),
    .sda_o(mux_sda_o),
    .sda_t(mux_sda_t),
    .data_in(mux_reg),
    .data_latch(1'b0),
    .data_out(mux_reg)
);

reg en;
reg [PORTS-1:0] port;

reg [PORTS-1:0] master_scl_out;
reg [PORTS-1:0] master_sda_out;
reg master_scl_in;
reg master_sda_in;

reg slave_scl_r;
reg slave_sda_r;
reg [RISE_LEN-1:0] master_scl_r;
reg [RISE_LEN-1:0] master_sda_r;

assign slave_scl_o = slave_scl_r;
assign slave_sda_o = slave_sda_r;
assign master_scl_o = master_scl_out;
assign master_sda_o = master_sda_out;

assign slave_scl_t = slave_scl_r;
assign slave_sda_t = slave_sda_r;
assign master_scl_t = master_scl_out;
assign master_sda_t = master_sda_out;

assign selected_port = port;

/* select master port if a port is selected */
always @(*) begin
    master_scl_out = {PORTS{1'b1}};
    master_sda_out = {PORTS{1'b1}};
    master_scl_in = 1'b1;
    master_sda_in = 1'b1;
    if (en) begin
        master_scl_out[port] = master_scl_r[0];
        master_sda_out[port] = master_sda_r[0];
        master_scl_in = master_scl_i[port];
        master_sda_in = master_sda_i[port];
    end
end

always @(posedge clk) begin
    port <= 0;
    en <= 1'b0;
    if (mux_reg >= 4 && mux_reg < PORTS + 4) begin
        port <= mux_reg - 4;
        en <= 1'b1;
    end
end

/* need to do some filtering when going from driving low to high-z with real IO */
wire master_scl_filter;
wire master_sda_filter;
assign master_scl_filter = (master_scl_r != {RISE_LEN{1'b1}}) ? 1'b1 : 1'b0;
assign master_sda_filter = (master_sda_r != {RISE_LEN{1'b1}}) ? 1'b1 : 1'b0;

always @(posedge clk) begin
    master_scl_r <= {master_scl_r[RISE_LEN-2:0], (slave_scl_i || !slave_scl_r)};
    master_sda_r <= {master_sda_r[RISE_LEN-2:0], (slave_sda_i || !slave_sda_r)};
    slave_scl_r <= (master_scl_in || master_scl_filter) & (mux_scl_t | mux_scl_o);
    slave_sda_r <= (master_sda_in || master_sda_filter) & (mux_sda_t | mux_sda_o);
end

endmodule

`resetall

