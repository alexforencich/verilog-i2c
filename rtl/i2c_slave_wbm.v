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
 * I2C slave wishbone master wrapper
 */
module i2c_slave_wbm #(
    parameter FILTER_LEN      = 4,
    parameter WB_DATA_WIDTH   = 32,                  // width of data bus in bits (8, 16, 32, or 64)
    parameter WB_ADDR_WIDTH   = 32,                  // width of address bus in bits
    parameter WB_SELECT_WIDTH = (WB_DATA_WIDTH / 8)  // width of word select bus (1, 2, 4, or 8)
) (
    input wire clk,
    input wire rst,

    /*
     * I2C interface
     */
    input  wire i2c_scl_i,
    output wire i2c_scl_o,
    output wire i2c_scl_t,
    input  wire i2c_sda_i,
    output wire i2c_sda_o,
    output wire i2c_sda_t,

    /*
     * Wishbone interface
     */
    output wire [  WB_ADDR_WIDTH-1:0] wb_adr_o,  // ADR_O() address
    input  wire [  WB_DATA_WIDTH-1:0] wb_dat_i,  // DAT_I() data in
    output wire [  WB_DATA_WIDTH-1:0] wb_dat_o,  // DAT_O() data out
    output wire                       wb_we_o,   // WE_O write enable output
    output wire [WB_SELECT_WIDTH-1:0] wb_sel_o,  // SEL_O() select output
    output wire                       wb_stb_o,  // STB_O strobe output
    input  wire                       wb_ack_i,  // ACK_I acknowledge input
    input  wire                       wb_err_i,  // ERR_I error input
    output wire                       wb_cyc_o,  // CYC_O cycle output

    /*
     * Status
     */
    output wire busy,
    output wire bus_addressed,
    output wire bus_active,

    /*
     * Configuration
     */
    input wire       enable,
    input wire [6:0] device_address
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

This module enables I2C control over a Wishbone bus, useful for enabling a
design to operate as a peripheral to an external microcontroller or similar.
The Wishbone interface are fully parametrizable, with the restriction that the
bus must be divided into 2**m words of 8*2**n bits.

Writing via I2C first accesses an internal address register, followed by the
actual wishbone bus.  The first k bytes go to the address register, where

    k = ceil(log2(WB_ADDR_WIDTH+log2(WB_DATA_WIDTH/WB_SELECT_WIDTH))/8)

.  The address pointer will automatically increment with reads and writes.
For buses with word size > 8 bits, the address register is in bytes and
unaligned writes will be padded with zeros.  Writes to the same bus address in
the same I2C transaction are coalesced and written either once a complete
word is ready or when the I2C transaction terminates with a stop or repeated
start.

Reading via the I2C interface immediately starts reading from the Wishbone
interface starting from the current value of the internal address register.
Like writes, reads are also coalesced when possible.  One wishbone read is
performed on the first I2C read.  Once that has been completey transferred
out, another read will be performed on the start of the next I2C read
operation.

Read
_   _ _ _ _ _ _ _ _   _ _ _ _ _ _ _ _         _ _ _ _ _ _ _ _   _   _ _ _ _ _ _ _     _ _ _ _ _ _ _ _         _ _ _ _ _ _ _ _ _   _
 |_|_|_|_|_|_|_|_| |_|_|_|_|_|_|_|_|_|_ ... _|_|_|_|_|_|_|_|_|_| |_|_|_|_|_|_|_|_|___|_|_|_|_|_|_|_|_|_ ... _|_|_|_|_|_|_|_|_| |_|

ST  Device Addr   W A   Address MSB   A         Address LSB   A  RS Device Addr   R A   Data byte 0   A         Data byte N   N  SP

Write
_   _ _ _ _ _ _ _ _   _ _ _ _ _ _ _ _         _ _ _ _ _ _ _ _   _ _ _ _ _ _ _ _         _ _ _ _ _ _ _ _     _
 |_|_|_|_|_|_|_|_| |_|_|_|_|_|_|_|_|_|_ ... _|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_ ... _|_|_|_|_|_|_|_|_|___|

ST  Device Addr   W A   Address MSB   A         Address LSB   A   Data byte 0   A         Data byte N   A  SP

Status:

busy
    module is communicating over the bus

bus_control
    module has control of bus in active state

bus_active
    bus is active, not necessarily controlled by this module

Parameters:

device_address
    address of slave device

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

  // for interfaces that are more than one word wide, disable address lines
  parameter WB_VALID_ADDR_WIDTH = WB_ADDR_WIDTH - $clog2(WB_SELECT_WIDTH);
  // width of data port in words (1, 2, 4, or 8)
  parameter WB_WORD_WIDTH = WB_SELECT_WIDTH;
  // size of words (8, 16, 32, or 64 bits)
  parameter WB_WORD_SIZE = WB_DATA_WIDTH / WB_WORD_WIDTH;

  parameter WORD_PART_ADDR_WIDTH = $clog2(WB_WORD_SIZE / 8);

  parameter ADDR_WIDTH_ADJ = WB_ADDR_WIDTH + WORD_PART_ADDR_WIDTH;

  parameter ADDR_WORD_WIDTH = (ADDR_WIDTH_ADJ + 7) / 8;

  // bus width assertions
  initial begin
    if (WB_WORD_WIDTH * WB_WORD_SIZE != WB_DATA_WIDTH) begin
      $error("Error: WB data width not evenly divisble");
      $finish;
    end

    if (2 ** $clog2(WB_WORD_WIDTH) != WB_WORD_WIDTH) begin
      $error("Error: WB word width must be even power of two");
      $finish;
    end

    if (8 * 2 ** $clog2(WB_WORD_SIZE / 8) != WB_WORD_SIZE) begin
      $error("Error: WB word size must be a power of two multiple of 8 bits");
      $finish;
    end
  end

  localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_ADDRESS = 3'd1,
    STATE_READ_1 = 3'd2,
    STATE_READ_2 = 3'd3,
    STATE_WRITE_1 = 3'd4,
    STATE_WRITE_2 = 3'd5;

  reg [2:0] state_reg = STATE_IDLE, state_next;

  reg [7:0] count_reg = 8'd0, count_next;
  reg last_cycle_reg = 1'b0;

  reg [ADDR_WIDTH_ADJ-1:0] addr_reg = {ADDR_WIDTH_ADJ{1'b0}}, addr_next;
  reg [WB_DATA_WIDTH-1:0] data_reg = {WB_DATA_WIDTH{1'b0}}, data_next;

  reg wb_we_o_reg = 1'b0, wb_we_o_next;
  reg [WB_SELECT_WIDTH-1:0] wb_sel_o_reg = {WB_SELECT_WIDTH{1'b0}}, wb_sel_o_next;
  reg wb_stb_o_reg = 1'b0, wb_stb_o_next;
  reg wb_cyc_o_reg = 1'b0, wb_cyc_o_next;

  reg busy_reg = 1'b0;

  reg [7:0] data_in_reg = 8'd0, data_in_next;
  reg data_in_valid_reg = 1'b0, data_in_valid_next;
  wire data_in_ready;

  wire [7:0] data_out;
  wire data_out_valid;
  wire data_out_last;
  reg data_out_ready_reg = 1'b0, data_out_ready_next;

  assign wb_adr_o = {
    addr_reg[ADDR_WIDTH_ADJ-1:ADDR_WIDTH_ADJ-WB_VALID_ADDR_WIDTH],
    {WB_ADDR_WIDTH - WB_VALID_ADDR_WIDTH{1'b0}}
  };
  assign wb_dat_o = data_reg;
  assign wb_we_o = wb_we_o_reg;
  assign wb_sel_o = wb_sel_o_reg;
  assign wb_stb_o = wb_stb_o_reg;
  assign wb_cyc_o = wb_cyc_o_reg;

  assign busy = busy_reg;

  always @* begin
    state_next = STATE_IDLE;

    count_next = count_reg;

    data_in_next = 8'd0;
    data_in_valid_next = 1'b0;

    data_out_ready_next = 1'b0;

    addr_next = addr_reg;
    data_next = data_reg;

    wb_we_o_next = wb_we_o_reg;
    wb_sel_o_next = wb_sel_o_reg;
    wb_stb_o_next = 1'b0;
    wb_cyc_o_next = 1'b0;

    case (state_reg)
      STATE_IDLE: begin
        // idle, wait for I2C interface
        wb_we_o_next = 1'b0;

        if (data_out_valid) begin
          // store address and write
          count_next = ADDR_WORD_WIDTH - 1;
          state_next = STATE_ADDRESS;
        end else if (data_in_ready & ~data_in_valid_reg) begin
          // read
          wb_cyc_o_next = 1'b1;
          wb_stb_o_next = 1'b1;
          wb_sel_o_next = {WB_SELECT_WIDTH{1'b1}};
          state_next = STATE_READ_1;
        end
      end
      STATE_ADDRESS: begin
        // store address
        data_out_ready_next = 1'b1;

        if (data_out_ready_reg & data_out_valid) begin
          // store pointers
          addr_next[8*count_reg+:8] = data_out;
          count_next = count_reg - 1;
          if (count_reg == 0) begin
            // end of header
            // set initial word offset
            if (WB_ADDR_WIDTH == WB_VALID_ADDR_WIDTH && WORD_PART_ADDR_WIDTH == 0) begin
              count_next = 0;
            end else begin
              count_next = addr_next[ADDR_WIDTH_ADJ-WB_VALID_ADDR_WIDTH-1:0];
            end
            wb_sel_o_next = {WB_SELECT_WIDTH{1'b0}};
            data_next = {WB_DATA_WIDTH{1'b0}};
            if (data_out_last) begin
              // end of transaction
              state_next = STATE_IDLE;
            end else begin
              // start writing
              state_next = STATE_WRITE_1;
            end
          end else begin
            if (data_out_last) begin
              // end of transaction
              state_next = STATE_IDLE;
            end else begin
              state_next = STATE_ADDRESS;
            end
          end
        end else begin
          state_next = STATE_ADDRESS;
        end
      end
      STATE_READ_1: begin
        // wait for ack
        wb_cyc_o_next = 1'b1;
        wb_stb_o_next = 1'b1;

        if (wb_ack_i || wb_err_i) begin
          // read cycle complete, store result
          data_next = wb_dat_i;
          addr_next = addr_reg + (1 << (WB_ADDR_WIDTH-WB_VALID_ADDR_WIDTH+WORD_PART_ADDR_WIDTH));
          wb_cyc_o_next = 1'b0;
          wb_stb_o_next = 1'b0;
          wb_sel_o_next = {WB_SELECT_WIDTH{1'b0}};
          state_next = STATE_READ_2;
        end else begin
          state_next = STATE_READ_1;
        end
      end
      STATE_READ_2: begin
        // send data
        if (data_out_valid | !bus_addressed) begin
          // no longer addressed or now addressed for write, return to idle
          state_next = STATE_IDLE;
        end else if (data_in_ready & ~data_in_valid_reg) begin
          // transfer word and update pointers
          data_in_next = data_reg[8*count_reg+:8];
          data_in_valid_next = 1'b1;
          count_next = count_reg + 1;
          if (count_reg == (WB_SELECT_WIDTH * WB_WORD_SIZE / 8) - 1) begin
            // end of stored data word; return to idle
            count_next = 0;
            state_next = STATE_IDLE;
          end else begin
            state_next = STATE_READ_2;
          end
        end else begin
          state_next = STATE_READ_2;
        end
      end
      STATE_WRITE_1: begin
        // write data
        data_out_ready_next = 1'b1;

        if (data_out_ready_reg & data_out_valid) begin
          // store word
          data_next[8*count_reg+:8] = data_out;
          count_next = count_reg + 1;
          wb_sel_o_next[count_reg>>((WB_WORD_SIZE/8)-1)] = 1'b1;
          if (count_reg == (WB_SELECT_WIDTH * WB_WORD_SIZE / 8) - 1 || data_out_last) begin
            // have full word or at end of block, start write operation
            count_next = 0;
            wb_we_o_next = 1'b1;
            wb_cyc_o_next = 1'b1;
            wb_stb_o_next = 1'b1;
            state_next = STATE_WRITE_2;
          end else begin
            state_next = STATE_WRITE_1;
          end
        end else begin
          state_next = STATE_WRITE_1;
        end
      end
      STATE_WRITE_2: begin
        // wait for ack
        wb_cyc_o_next = 1'b1;
        wb_stb_o_next = 1'b1;

        if (wb_ack_i || wb_err_i) begin
          // end of write operation
          data_next = {WB_DATA_WIDTH{1'b0}};
          addr_next = addr_reg + (1 << (WB_ADDR_WIDTH-WB_VALID_ADDR_WIDTH+WORD_PART_ADDR_WIDTH));
          wb_cyc_o_next = 1'b0;
          wb_stb_o_next = 1'b0;
          wb_sel_o_next = {WB_SELECT_WIDTH{1'b0}};
          if (last_cycle_reg) begin
            // end of transaction
            state_next = STATE_IDLE;
          end else begin
            state_next = STATE_WRITE_1;
          end
        end else begin
          state_next = STATE_WRITE_2;
        end
      end
    endcase
  end

  always @(posedge clk) begin
    state_reg <= state_next;

    count_reg <= count_next;

    if (data_out_ready_reg & data_out_valid) begin
      last_cycle_reg <= data_out_last;
    end

    addr_reg <= addr_next;
    data_reg <= data_next;

    wb_we_o_reg <= wb_we_o_next;
    wb_sel_o_reg <= wb_sel_o_next;
    wb_stb_o_reg <= wb_stb_o_next;
    wb_cyc_o_reg <= wb_cyc_o_next;

    busy_reg <= state_next != STATE_IDLE;

    data_in_reg <= data_in_next;
    data_in_valid_reg <= data_in_valid_next;

    data_out_ready_reg <= data_out_ready_next;

    if (rst) begin
      state_reg <= STATE_IDLE;
      data_in_valid_reg <= 1'b0;
      data_out_ready_reg <= 1'b0;
      wb_stb_o_reg <= 1'b0;
      wb_cyc_o_reg <= 1'b0;
      busy_reg <= 1'b0;
    end
  end

  i2c_slave #(
      .FILTER_LEN(FILTER_LEN)
  ) i2c_slave_inst (
      .clk(clk),
      .rst(rst),

      // Host interface
      .release_bus(1'b0),

      .s_axis_data_tdata (data_in_reg),
      .s_axis_data_tvalid(data_in_valid_reg),
      .s_axis_data_tready(data_in_ready),
      .s_axis_data_tlast (1'b0),

      .m_axis_data_tdata (data_out),
      .m_axis_data_tvalid(data_out_valid),
      .m_axis_data_tready(data_out_ready_reg),
      .m_axis_data_tlast (data_out_last),

      // I2C Interface
      .scl_i(i2c_scl_i),
      .scl_o(i2c_scl_o),
      .scl_t(i2c_scl_t),
      .sda_i(i2c_sda_i),
      .sda_o(i2c_sda_o),
      .sda_t(i2c_sda_t),

      // Status
      .busy(),
      .bus_address(),
      .bus_addressed(bus_addressed),
      .bus_active(bus_active),

      // Configuration
      .enable(enable),
      .device_address(device_address),
      .device_address_mask(7'h7f)
  );

endmodule
