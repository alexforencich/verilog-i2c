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

reg cmd_ready = 0;
reg data_out_ready = 0;
reg start = 0;

// Outputs
wire [6:0] cmd_address;
wire cmd_start;
wire cmd_read;
wire cmd_write;
wire cmd_write_multiple;
wire cmd_stop;
wire cmd_valid;
wire [7:0] data_out;
wire data_out_valid;
wire data_out_last;
wire busy;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        cmd_ready,
        data_out_ready,
        start);
    $to_myhdl(
        cmd_address,
        cmd_start,
        cmd_read,
        cmd_write,
        cmd_write_multiple,
        cmd_stop,
        cmd_valid,
        data_out,
        data_out_valid,
        data_out_last,
        busy
    );

    // dump file
    $dumpfile("test_i2c_init.lxt");
    $dumpvars(0, test_i2c_init);
end

i2c_init
UUT (
    .clk(clk),
    .rst(rst),
    .cmd_address(cmd_address),
    .cmd_start(cmd_start),
    .cmd_read(cmd_read),
    .cmd_write(cmd_write),
    .cmd_write_multiple(cmd_write_multiple),
    .cmd_stop(cmd_stop),
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),
    .data_out(data_out),
    .data_out_valid(data_out_valid),
    .data_out_ready(data_out_ready),
    .data_out_last(data_out_last),
    .busy(busy),
    .start(start)
);

endmodule
