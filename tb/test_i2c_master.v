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
 * Testbench for i2c_master
 */
module test_i2c_master;

// Parameters

// Inputs
reg clk = 0;
reg rst = 0;
reg [7:0] current_test = 0;

reg [6:0] cmd_address = 0;
reg cmd_start = 0;
reg cmd_read = 0;
reg cmd_write = 0;
reg cmd_write_multiple = 0;
reg cmd_stop = 0;
reg cmd_valid = 0;
reg [7:0] data_in = 0;
reg data_in_valid = 0;
reg data_in_last = 0;
reg data_out_ready = 0;
reg scl_i = 1;
reg sda_i = 1;
reg [15:0] prescale = 0;
reg stop_on_idle = 0;

// Outputs
wire cmd_ready;
wire data_in_ready;
wire [7:0] data_out;
wire data_out_valid;
wire data_out_last;
wire scl_o;
wire scl_t;
wire sda_o;
wire sda_t;
wire busy;
wire bus_control;
wire bus_active;
wire missed_ack;

initial begin
    // myhdl integration
    $from_myhdl(
        clk,
        rst,
        current_test,
        cmd_address,
        cmd_start,
        cmd_read,
        cmd_write,
        cmd_write_multiple,
        cmd_stop,
        cmd_valid,
        data_in,
        data_in_valid,
        data_in_last,
        data_out_ready,
        scl_i,
        sda_i,
        prescale,
        stop_on_idle
    );
    $to_myhdl(
        cmd_ready,
        data_in_ready,
        data_out,
        data_out_valid,
        data_out_last,
        scl_o,
        scl_t,
        sda_o,
        sda_t,
        busy,
        bus_control,
        bus_active,
        missed_ack
    );

    // dump file
    $dumpfile("test_i2c_master.lxt");
    $dumpvars(0, test_i2c_master);
end

i2c_master
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
    .data_in(data_in),
    .data_in_valid(data_in_valid),
    .data_in_ready(data_in_ready),
    .data_in_last(data_in_last),
    .data_out(data_out),
    .data_out_valid(data_out_valid),
    .data_out_ready(data_out_ready),
    .data_out_last(data_out_last),
    .scl_i(scl_i),
    .scl_o(scl_o),
    .scl_t(scl_t),
    .sda_i(sda_i),
    .sda_o(sda_o),
    .sda_t(sda_t),
    .busy(busy),
    .bus_control(bus_control),
    .bus_active(bus_active),
    .missed_ack(missed_ack),
    .prescale(prescale),
    .stop_on_idle(stop_on_idle)
);

endmodule
