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

`timescale 1ns / 1ps

module i2c_master_model #(
    parameter I2C_FREQUENCY = 100000
) (
    input  wire sda,
    output wire sda_o,
    input  wire scl,
    output wire scl_o
);

localparam I2C_PERIOD = 1000000000 / I2C_FREQUENCY; // 1ns / 100kHz
localparam I2C_HPERIOD = I2C_PERIOD / 2;
localparam I2C_QPERIOD = I2C_PERIOD / 4;

reg sda_r, scl_r;

assign sda_o = sda_r;
assign scl_o = scl_r;

task write;
    input [6:0] addr;
    input [7:0] data;
    integer I;
    reg [17:0] shift_reg;
begin
    $display("i2c_write @0x%0h data 0x%0h", addr, data);
    // addr, write, ack, data, ack
    shift_reg = { addr, 1'b0, 1'b1, data, 1'b1 };

    // start
    #(I2C_QPERIOD);
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b0;
    #(I2C_QPERIOD);

    for (I = 17; I >= 0 ; I = I-1) begin
        sda_r = shift_reg[I];
        #(I2C_QPERIOD);
        scl_r = 1'b1;
        #(I2C_QPERIOD);
        #(I2C_QPERIOD);
        scl_r = 1'b0;
        #(I2C_QPERIOD);
    end

    // stop
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b1;
    #(I2C_QPERIOD);
    sda_r = 1'b1;
end endtask

task read;
    input [6:0] addr;
    output [7:0] data;
    integer I;
    reg [9:0] shift_reg;
begin
    // addr, read, ack
    shift_reg = { addr, 1'b1, 1'b1 };

    // start
    #(I2C_QPERIOD);
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b0;
    #(I2C_QPERIOD);

    for (I = 8; I >= 0 ; I = I-1) begin
        sda_r = shift_reg[I];
        #(I2C_QPERIOD);
        scl_r = 1'b1;
        #(I2C_QPERIOD);
        #(I2C_QPERIOD);
        scl_r = 1'b0;
        #(I2C_QPERIOD);
    end

    sda_r = 1'b1;

    for (I = 7; I >= 0; I = I-1) begin
        #(I2C_QPERIOD);
        scl_r = 1'b1;
        #(I2C_QPERIOD);
        data[I] = (sda === 1'b0) ? 1'b0 : 1'b1;
        #(I2C_QPERIOD);
        scl_r = 1'b0;
        #(I2C_QPERIOD);
    end

    $display("i2c_read @0x%0h data 0x%0h", addr, data);

    // nack
    sda_r = 1'b1;
    #(I2C_QPERIOD);
    scl_r = 1'b1;
    #(I2C_QPERIOD);
    #(I2C_QPERIOD);

    // stop
    scl_r = 1'b0;
    #(I2C_QPERIOD);
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b1;
    #(I2C_QPERIOD);
    sda_r = 1'b1;
end endtask

task smbus_write;
    input [6:0] addr;
    input [7:0] cmd;
    input [7:0] data;
    integer I;
    reg [26:0] shift_reg;
begin
    $display("smbus_write @0x%0h cmd 0x%0h data 0x%0h", addr, cmd, data);
    // addr, write, ack, cmd, ack, data, ack
    shift_reg = { addr, 1'b0, 1'b1, cmd, 1'b1, data, 1'b1 };

    // start
    #(I2C_QPERIOD);
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b0;
    #(I2C_QPERIOD);

    for (I = 26; I >= 0 ; I = I-1) begin
        sda_r = shift_reg[I];
        #(I2C_QPERIOD);
        scl_r = 1'b1;
        #(I2C_QPERIOD);
        #(I2C_QPERIOD);
        scl_r = 1'b0;
        #(I2C_QPERIOD);
    end

    // stop
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b1;
    #(I2C_QPERIOD);
    sda_r = 1'b1;

end endtask

task smbus_read;
    input [6:0] addr;
    input [7:0] cmd;
    output [7:0] data;
    integer I;
    reg [17:0] shift_reg;
begin
    // addr, write, ack, cmd, ack
    shift_reg = { addr, 1'b0, 1'b1, cmd, 1'b1 };

    // start
    #(I2C_QPERIOD);
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b0;
    #(I2C_QPERIOD);

    for (I = 17; I >= 0 ; I = I-1) begin
        sda_r = shift_reg[I];
        #(I2C_QPERIOD);
        scl_r = 1'b1;
        #(I2C_QPERIOD);
        #(I2C_QPERIOD);
        scl_r = 1'b0;
        #(I2C_QPERIOD);
    end

    // repeated start
    sda_r = 1'b1;
    #(I2C_QPERIOD);
    scl_r = 1'b1;
    #(I2C_QPERIOD);
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b0;
    #(I2C_QPERIOD);

    // addr, read, ack
    shift_reg = { addr, 1'b1, 1'b1 };

    for (I = 8; I >= 0 ; I = I-1) begin
        sda_r = shift_reg[I];
        #(I2C_QPERIOD);
        scl_r = 1'b1;
        #(I2C_QPERIOD);
        #(I2C_QPERIOD);
        scl_r = 1'b0;
        #(I2C_QPERIOD);
    end

    sda_r = 1'b1;

    for (I = 7; I >= 0; I = I-1) begin
        #(I2C_QPERIOD);
        scl_r = 1'b1;
        #(I2C_QPERIOD);
        data[I] = (sda === 1'b0) ? 1'b0 : 1'b1;
        #(I2C_QPERIOD);
        scl_r = 1'b0;
        #(I2C_QPERIOD);
    end

    $display("smbus_read @0x%0h cmd 0x%0h data 0x%0h", addr, cmd, data);

    // nack
    sda_r = 1'b1;
    #(I2C_QPERIOD);
    scl_r = 1'b1;
    #(I2C_QPERIOD);
    #(I2C_QPERIOD);

    // stop
    scl_r = 1'b0;
    #(I2C_QPERIOD);
    sda_r = 1'b0;
    #(I2C_QPERIOD);
    scl_r = 1'b1;
    #(I2C_QPERIOD);
    sda_r = 1'b1;
end endtask



endmodule
