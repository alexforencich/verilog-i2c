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
    parameter DEV_ADDR = 7'h70
)
(
    input wire        clk,
    input wire        rst,
    output wire [3:0] selected_port,

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
    input  wire [3:0] master_scl_i,
    output wire [3:0] master_scl_o,
    output wire [3:0] master_scl_t,
    input  wire [3:0] master_sda_i,
    output wire [3:0] master_sda_o,
    output wire [3:0] master_sda_t
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

reg [3:0] port;

reg slave_scl_r;
reg slave_sda_r;
reg [3:0] master_scl_r;
reg [3:0] master_sda_r;

assign slave_scl_o = slave_scl_t;
assign slave_sda_o = slave_sda_t;
assign master_scl_o = master_scl_t;
assign master_sda_o = master_sda_t;

assign slave_scl_t = slave_scl_r;
assign slave_sda_t = slave_sda_r;
assign master_scl_t = master_scl_r;
assign master_sda_t = master_sda_r;

assign selected_port = port;

always @(posedge clk) begin
    master_scl_r <= 4'hf;
    master_sda_r <= 4'hf;
    slave_scl_r <= mux_scl_t || mux_scl_o;
    slave_sda_r <= mux_sda_t || mux_sda_o;

    case (mux_reg[2:0])
    3'b100: begin
        port <= 4'b0001;
        master_scl_r[0] <= slave_scl_i || !slave_scl_t;
        master_sda_r[0] <= slave_sda_i || !slave_sda_t;
        slave_scl_r <= (master_scl_i[0] || !master_scl_t[0]) && (mux_scl_t || mux_scl_o);
        slave_sda_r <= (master_sda_i[0] || !master_sda_t[0]) && (mux_sda_t || mux_sda_o);
    end
    3'b101: begin
        port <= 4'b0010;
        master_scl_r[1] <= slave_scl_i || !slave_scl_t;
        master_sda_r[1] <= slave_sda_i || !slave_sda_t;
        slave_scl_r <= (master_scl_i[1] || !master_scl_t[1]) && (mux_scl_t || mux_scl_o);
        slave_sda_r <= (master_sda_i[1] || !master_sda_t[1]) && (mux_sda_t || mux_sda_o);
    end
    3'b110: begin
        port <= 4'b0100;
        master_scl_r[2] <= slave_scl_i || !slave_scl_t;
        master_sda_r[2] <= slave_sda_i || !slave_sda_t;
        slave_scl_r <= (master_scl_i[2] || !master_scl_t[2]) && (mux_scl_t || mux_scl_o);
        slave_sda_r <= (master_sda_i[2] || !master_sda_t[2]) && (mux_sda_t || mux_sda_o);
    end
    3'b111: begin
        port <= 4'b1000;
        master_scl_r[3] <= slave_scl_i || !slave_scl_t;
        master_sda_r[3] <= slave_sda_i || !slave_sda_t;
        slave_scl_r <= (master_scl_i[3] || !master_scl_t[3]) && (mux_scl_t || mux_scl_o);
        slave_sda_r <= (master_sda_i[3] || !master_sda_t[3]) && (mux_sda_t || mux_sda_o);
    end
    default: begin
        port <= 4'b0000;
    end endcase

end

endmodule

`resetall

