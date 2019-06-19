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
 * I2C slave
 */
module i2c_slave #(
    parameter FILTER_LEN = 4
)
(
    input wire         clk,
    input wire         rst,

    /*
     * Host interface
     */
    input  wire        release_bus,

    input  wire [7:0]  data_in,
    input  wire        data_in_valid,
    output wire        data_in_ready,
    input  wire        data_in_last,

    output wire [7:0]  data_out,
    output wire        data_out_valid,
    input  wire        data_out_ready,
    output wire        data_out_last,

    /*
     * I2C interface
     */
    input  wire        scl_i,
    output wire        scl_o,
    output wire        scl_t,
    input  wire        sda_i,
    output wire        sda_o,
    output wire        sda_t,

    /*
     * Status
     */
    output wire        busy,
    output wire [6:0]  bus_address,
    output wire        bus_addressed,
    output wire        bus_active,

    /*
     * Configuration
     */
    input  wire        enable,
    input  wire [6:0]  device_address,
    input  wire [6:0]  device_address_mask
);
/*

I2C

Read
    __    ___ ___ ___ ___ ___ ___ ___         ___ ___ ___ ___ ___ ___ ___ ___     ___ ___ ___ ___ ___ ___ ___ ___        __
sda   \__/_6_X_5_X_4_X_3_X_2_X_1_X_0_\_R___A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_\_A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_\_A____/
    ____   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   ____
scl  ST \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ SP

Write
    __    ___ ___ ___ ___ ___ ___ ___ ___     ___ ___ ___ ___ ___ ___ ___ ___     ___ ___ ___ ___ ___ ___ ___ ___ ___    __
sda   \__/_6_X_5_X_4_X_3_X_2_X_1_X_0_/ W \_A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_\_A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_/ N \__/
    ____   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   ____
scl  ST \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ SP


Operation:

This module translates I2C read and write operations into AXI stream transfers.
Bytes written over I2C will be delayed by one byte time so that the last byte
in a write operation can be accurately marked.  When reading, the module will
stretch SCL by holding it low until a data byte is presented at the AXI stream
input.  

Control:

release_bus
    releases control over bus

Status:

busy
    module is communicating over the bus

bus_address
    active address on bus when module is addressed

bus_addressed
    module is currently addressed on the bus

bus_active
    bus is active, not necessarily controlled by this module

Parameters:

device_address
    address of slave device

device_address_mask
    select which bits of device address to compare, set to 7'h7f
    to check all bits (single address device)

Example of interfacing with tristate pins:
(this will work for any tristate bus)

assign scl_i = scl_pin;
assign scl_pin = scl_t ? 1'bz : scl_o;
assign sda_i = sda_pin;
assign sda_pin = sda_t ? 1'bz : sda_o;

Equivalent code that does not use *_t connections:
(we can get away with this because I2C is open-drain)

assign scl_i = scl_pin;
assign scl_pin = scl_o ? 1'bz : 1'b0;
assign sda_i = sda_pin;
assign sda_pin = sda_o ? 1'bz : 1'b0;

Example of two interconnected I2C devices:

assign scl_1_i = scl_1_o & scl_2_o;
assign scl_2_i = scl_1_o & scl_2_o;
assign sda_1_i = sda_1_o & sda_2_o;
assign sda_2_i = sda_1_o & sda_2_o;

Example of two I2C devices sharing the same pins:

assign scl_1_i = scl_pin;
assign scl_2_i = scl_pin;
assign scl_pin = (scl_1_o & scl_2_o) ? 1'bz : 1'b0;
assign sda_1_i = sda_pin;
assign sda_2_i = sda_pin;
assign sda_pin = (sda_1_o & sda_2_o) ? 1'bz : 1'b0;

Notes:

scl_o should not be connected directly to scl_i, only via AND logic or a tristate
I/O pin.  This would prevent devices from stretching the clock period.

*/

localparam [4:0]
    STATE_IDLE = 4'd0,
    STATE_ADDRESS = 4'd1,
    STATE_ACK = 4'd2,
    STATE_WRITE_1 = 4'd3,
    STATE_WRITE_2 = 4'd4,
    STATE_READ_1 = 4'd5,
    STATE_READ_2 = 4'd6,
    STATE_READ_3 = 4'd7;

reg [4:0] state_reg = STATE_IDLE, state_next;

reg [6:0] addr_reg = 7'd0, addr_next;
reg [7:0] data_reg = 8'd0, data_next;
reg data_valid_reg = 1'b0, data_valid_next;
reg data_out_reg_valid_reg = 1'b0, data_out_reg_valid_next;
reg last_reg = 1'b0, last_next;

reg mode_read_reg = 1'b0, mode_read_next;

reg [3:0] bit_count_reg = 4'd0, bit_count_next;

reg data_in_ready_reg = 1'b0, data_in_ready_next;

reg [7:0] data_out_reg = 8'd0, data_out_next;
reg data_out_valid_reg = 1'b0, data_out_valid_next;
reg data_out_last_reg = 1'b0, data_out_last_next;

reg [FILTER_LEN-1:0] scl_i_filter = {FILTER_LEN{1'b1}};
reg [FILTER_LEN-1:0] sda_i_filter = {FILTER_LEN{1'b1}};

reg scl_i_reg = 1'b1;
reg sda_i_reg = 1'b1;

reg scl_o_reg = 1'b1, scl_o_next;
reg sda_o_reg = 1'b1, sda_o_next;

reg last_scl_i_reg = 1'b1;
reg last_sda_i_reg = 1'b1;

reg busy_reg = 1'b0;
reg bus_active_reg = 1'b0;
reg bus_addressed_reg = 1'b0, bus_addressed_next;

assign bus_address = addr_reg;

assign data_in_ready = data_in_ready_reg;

assign data_out = data_out_reg;
assign data_out_valid = data_out_valid_reg;
assign data_out_last = data_out_last_reg;

assign scl_o = scl_o_reg;
assign scl_t = scl_o_reg;
assign sda_o = sda_o_reg;
assign sda_t = sda_o_reg;

assign busy = busy_reg;
assign bus_active = bus_active_reg;
assign bus_addressed = bus_addressed_reg;

assign scl_posedge = scl_i_reg && !last_scl_i_reg;
assign scl_negedge = !scl_i_reg && last_scl_i_reg;
assign sda_posedge = sda_i_reg && !last_sda_i_reg;
assign sda_negedge = !sda_i_reg && last_sda_i_reg;

assign start_bit = sda_negedge && scl_i_reg;
assign stop_bit = sda_posedge && scl_i_reg;

always @* begin
    state_next = STATE_IDLE;

    addr_next = addr_reg;
    data_next = data_reg;
    data_valid_next = data_valid_reg;
    data_out_reg_valid_next = data_out_reg_valid_reg;
    last_next = last_reg;

    mode_read_next = mode_read_reg;

    bit_count_next = bit_count_reg;

    data_in_ready_next = 1'b0;

    data_out_next = data_out_reg;
    data_out_valid_next = data_out_valid_reg && !data_out_ready;
    data_out_last_next = data_out_last_reg;

    scl_o_next = scl_o_reg;
    sda_o_next = sda_o_reg;

    bus_addressed_next = bus_addressed_reg;

    if (start_bit) begin
        // got start bit, latch out data, read address
        data_valid_next = 1'b0;
        data_out_reg_valid_next = 1'b0;
        bit_count_next = 4'd7;
        data_out_last_next = 1'b1;
        data_out_valid_next = data_out_reg_valid_reg;
        bus_addressed_next = 1'b0;
        state_next = STATE_ADDRESS;
    end else if (release_bus || stop_bit) begin
        // got stop bit or release bus command, latch out data, return to idle
        scl_o_next = 1'b1;
        sda_o_next = 1'b1;
        
        data_valid_next = 1'b0;
        data_out_reg_valid_next = 1'b0;
        data_out_last_next = 1'b1;
        data_out_valid_next = data_out_reg_valid_reg;
        bus_addressed_next = 1'b0;
        state_next = STATE_IDLE;
    end else begin
        case (state_reg)
            STATE_IDLE: begin
                // line idle
                scl_o_next = 1'b1;
                sda_o_next = 1'b1;
        
                data_valid_next = 1'b0;
                data_out_reg_valid_next = 1'b0;
                bus_addressed_next = 1'b0;
                state_next = STATE_IDLE;
            end
            STATE_ADDRESS: begin
                // read address
                if (scl_posedge) begin
                    if (bit_count_reg > 0) begin
                        // shift in address
                        bit_count_next = bit_count_reg-1;
                        data_next = {data_reg[6:0], sda_i_reg};
                        state_next = STATE_ADDRESS;
                    end else begin
                        // check address
                        if (enable && (device_address & device_address_mask) == (data_reg[6:0] & device_address_mask)) begin
                            // it's a match, save read/write bit and send ACK
                            addr_next = data_reg[6:0];
                            mode_read_next = sda_i_reg;
                            bus_addressed_next = 1'b1;
                            state_next = STATE_ACK;
                        end else begin
                            // no match, return to idle
                            state_next = STATE_IDLE;
                        end
                    end
                end else begin
                    state_next = STATE_ADDRESS;
                end
            end
            STATE_ACK: begin
                // send ACK bit
                if (scl_negedge) begin
                    sda_o_next = 1'b0;
                    bit_count_next = 4'd7;
                    if (mode_read_reg) begin
                        // reading
                        data_in_ready_next = 1'b1;
                        data_valid_next = 1'b0;
                        state_next = STATE_READ_1;
                    end else begin
                        // writing
                        state_next = STATE_WRITE_1;
                    end
                end else begin
                    state_next = STATE_ACK;
                end
            end
            STATE_WRITE_1: begin
                // write data byte
                if (scl_negedge || !scl_o_reg) begin
                    sda_o_next = 1'b1;
                    if (data_out_valid && !data_out_ready) begin
                        // data waiting in output register, so stretch clock
                        scl_o_next = 1'b0;
                        state_next = STATE_WRITE_1;
                    end else begin
                        scl_o_next = 1'b1;
                        if (data_valid_reg) begin
                            // store data in output register
                            data_out_next = data_reg;
                            data_out_last_next = 1'b0;
                        end
                        data_valid_next = 1'b0;
                        data_out_reg_valid_next = data_valid_reg;
                        state_next = STATE_WRITE_2;
                    end
                end else begin
                    state_next = STATE_WRITE_1;
                end
            end
            STATE_WRITE_2: begin
                // write data byte
                if (scl_posedge) begin
                    // shift in data bit
                    data_next = {data_reg[6:0], sda_i_reg};
                    if (bit_count_reg > 0) begin
                        bit_count_next = bit_count_reg-1;
                        state_next = STATE_WRITE_2;
                    end else begin
                        // latch out previous data byte since we now know it's not the last one
                        data_out_valid_next = data_out_reg_valid_reg;
                        data_out_reg_valid_next = 1'b0;
                        data_valid_next = 1'b1;
                        state_next = STATE_ACK;
                    end
                end else begin
                    state_next = STATE_WRITE_2;
                end
            end
            STATE_READ_1: begin
                // read data byte
                if (data_in_ready && data_in_valid) begin
                    // data valid; latch it in
                    data_in_ready_next = 1'b0;
                    data_next = data_in;
                    data_valid_next = 1'b1;
                end else begin
                    // keep ready high if we're waiting for data
                    data_in_ready_next = !data_valid_reg;
                end

                if (scl_negedge || !scl_o_reg) begin
                    // shift out data bit
                    if (!data_valid_reg) begin
                        // waiting for data, so stretch clock
                        scl_o_next = 1'b0;
                        state_next = STATE_READ_1;
                    end else begin
                        scl_o_next = 1'b1;
                        {sda_o_next, data_next} = {data_reg, 1'b0};
                        
                        if (bit_count_reg > 0) begin
                            bit_count_next = bit_count_reg-1;
                            state_next = STATE_READ_1;
                        end else begin
                            state_next = STATE_READ_2;
                        end
                    end
                end else begin
                    state_next = STATE_READ_1;
                end
            end
            STATE_READ_2: begin
                // read ACK bit
                if (scl_negedge) begin
                    // release SDA
                    sda_o_next = 1'b1;
                    state_next = STATE_READ_3;
                end else begin
                    state_next = STATE_READ_2;
                end
            end
            STATE_READ_3: begin
                // read ACK bit
                if (scl_posedge) begin
                    if (sda_i_reg) begin
                        // NACK, return to idle
                        state_next = STATE_IDLE;
                    end else begin
                        // ACK, read another byte
                        bit_count_next = 4'd7;
                        data_in_ready_next = 1'b1;
                        data_valid_next = 1'b0;
                        state_next = STATE_READ_1;
                    end
                end else begin
                    state_next = STATE_READ_3;
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        data_in_ready_reg <= 1'b0;
        data_out_valid_reg <= 1'b0;
        scl_o_reg <= 1'b1;
        sda_o_reg <= 1'b1;
        busy_reg <= 1'b0;
        bus_active_reg <= 1'b0;
        bus_addressed_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        data_in_ready_reg <= data_in_ready_next;
        data_out_valid_reg <= data_out_valid_next;

        scl_o_reg <= scl_o_next;
        sda_o_reg <= sda_o_next;

        busy_reg <= !(state_reg == STATE_IDLE);

        if (start_bit) begin
            bus_active_reg <= 1'b1;
        end else if (stop_bit) begin
            bus_active_reg <= 1'b0;
        end else begin
            bus_active_reg <= bus_active_reg;
        end

        bus_addressed_reg <= bus_addressed_next;
    end

    addr_reg <= addr_next;
    data_reg <= data_next;
    data_valid_reg <= data_valid_next;
    data_out_reg_valid_reg <= data_out_reg_valid_next;
    last_reg <= last_next;

    mode_read_reg <= mode_read_next;

    bit_count_reg <= bit_count_next;

    data_out_reg <= data_out_next;
    data_out_last_reg <= data_out_last_next;

    scl_i_filter <= (scl_i_filter << 1) | scl_i;
    sda_i_filter <= (sda_i_filter << 1) | sda_i;

    if (scl_i_filter == {FILTER_LEN{1'b1}}) begin
        scl_i_reg <= 1'b1;
    end else if (scl_i_filter == {FILTER_LEN{1'b0}}) begin
        scl_i_reg <= 1'b0;
    end

    if (sda_i_filter == {FILTER_LEN{1'b1}}) begin
        sda_i_reg <= 1'b1;
    end else if (sda_i_filter == {FILTER_LEN{1'b0}}) begin
        sda_i_reg <= 1'b0;
    end

    last_scl_i_reg <= scl_i_reg;
    last_sda_i_reg <= sda_i_reg;
end

endmodule
