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
 * I2C slave AXI lite master wrapper
 */
module i2c_slave_axil_master #(
    parameter FILTER_LEN = 4,
    parameter DATA_WIDTH = 32,  // width of data bus in bits
    parameter ADDR_WIDTH = 16,  // width of address bus in bits
    parameter STRB_WIDTH = (DATA_WIDTH / 8)
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
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0] m_axil_awaddr,
    output wire [           2:0] m_axil_awprot,
    output wire                  m_axil_awvalid,
    input  wire                  m_axil_awready,
    output wire [DATA_WIDTH-1:0] m_axil_wdata,
    output wire [STRB_WIDTH-1:0] m_axil_wstrb,
    output wire                  m_axil_wvalid,
    input  wire                  m_axil_wready,
    input  wire [           1:0] m_axil_bresp,
    input  wire                  m_axil_bvalid,
    output wire                  m_axil_bready,
    output wire [ADDR_WIDTH-1:0] m_axil_araddr,
    output wire [           2:0] m_axil_arprot,
    output wire                  m_axil_arvalid,
    input  wire                  m_axil_arready,
    input  wire [DATA_WIDTH-1:0] m_axil_rdata,
    input  wire [           1:0] m_axil_rresp,
    input  wire                  m_axil_rvalid,
    output wire                  m_axil_rready,

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

This module enables I2C control over an AXI lite bus, useful for enabling a
design to operate as a peripheral to an external microcontroller or similar.
The AXI lite interface are fully parametrizable, with the restriction that the
bus must be divided into 2**m words of 8*2**n bits.

Writing via I2C first accesses an internal address register, followed by the
actual AXI lite bus.  The first k bytes go to the address register, where

    k = ceil(log2(ADDR_WIDTH+log2(DATA_WIDTH/SELECT_WIDTH))/8)

.  The address pointer will automatically increment with reads and writes.
For buses with word size > 8 bits, the address register is in bytes and
unaligned writes will be padded with zeros.  Writes to the same bus address in
the same I2C transaction are coalesced and written either once a complete
word is ready or when the I2C transaction terminates with a stop or repeated
start.

Reading via the I2C interface immediately starts reading from the AXI lite
interface starting from the current value of the internal address register.
Like writes, reads are also coalesced when possible.  One AXI lite read is
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
  parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
  // width of data port in words
  parameter WORD_WIDTH = STRB_WIDTH;
  // size of words
  parameter WORD_SIZE = DATA_WIDTH / WORD_WIDTH;

  parameter WORD_PART_ADDR_WIDTH = $clog2(WORD_SIZE / 8);

  parameter ADDR_WIDTH_ADJ = ADDR_WIDTH + WORD_PART_ADDR_WIDTH;

  parameter ADDR_WORD_WIDTH = (ADDR_WIDTH_ADJ + 7) / 8;

  // bus width assertions
  initial begin
    if (WORD_WIDTH * WORD_SIZE != DATA_WIDTH) begin
      $error("Error: AXI data width not evenly divisble");
      $finish;
    end

    if (2 ** $clog2(WORD_WIDTH) != WORD_WIDTH) begin
      $error("Error: AXI word width must be even power of two");
      $finish;
    end

    if (8 * 2 ** $clog2(WORD_SIZE / 8) != WORD_SIZE) begin
      $error("Error: AXI word size must be a power of two multiple of 8 bits");
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
  reg [DATA_WIDTH-1:0] data_reg = {DATA_WIDTH{1'b0}}, data_next;

  reg m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
  reg [STRB_WIDTH-1:0] m_axil_wstrb_reg = {STRB_WIDTH{1'b0}}, m_axil_wstrb_next;
  reg m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
  reg m_axil_bready_reg = 1'b0, m_axil_bready_next;
  reg m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
  reg m_axil_rready_reg = 1'b0, m_axil_rready_next;

  reg busy_reg = 1'b0;

  reg [7:0] data_in_reg = 8'd0, data_in_next;
  reg data_in_valid_reg = 1'b0, data_in_valid_next;
  wire data_in_ready;

  wire [7:0] data_out;
  wire data_out_valid;
  wire data_out_last;
  reg data_out_ready_reg = 1'b0, data_out_ready_next;

  assign m_axil_awaddr = {
    addr_reg[ADDR_WIDTH_ADJ-1:ADDR_WIDTH_ADJ-VALID_ADDR_WIDTH],
    {ADDR_WIDTH - VALID_ADDR_WIDTH{1'b0}}
  };
  assign m_axil_awprot = 3'b010;
  assign m_axil_awvalid = m_axil_awvalid_reg;
  assign m_axil_wdata = data_reg;
  assign m_axil_wstrb = m_axil_wstrb_reg;
  assign m_axil_wvalid = m_axil_wvalid_reg;
  assign m_axil_bready = m_axil_bready_reg;
  assign m_axil_araddr = {
    addr_reg[ADDR_WIDTH_ADJ-1:ADDR_WIDTH_ADJ-VALID_ADDR_WIDTH],
    {ADDR_WIDTH - VALID_ADDR_WIDTH{1'b0}}
  };
  assign m_axil_arprot = 3'b010;
  assign m_axil_arvalid = m_axil_arvalid_reg;
  assign m_axil_rready = m_axil_rready_reg;

  assign busy = busy_reg;

  always @* begin
    state_next = STATE_IDLE;

    count_next = count_reg;

    data_in_next = 8'd0;
    data_in_valid_next = 1'b0;

    data_out_ready_next = 1'b0;

    addr_next = addr_reg;
    data_next = data_reg;

    m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_awready;
    m_axil_wstrb_next = m_axil_wstrb_reg;
    m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wready;
    m_axil_bready_next = 1'b0;
    m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_arready;
    m_axil_rready_next = 1'b0;

    case (state_reg)
      STATE_IDLE: begin
        // idle, wait for I2C interface

        if (data_out_valid) begin
          // store address and write
          count_next = ADDR_WORD_WIDTH - 1;
          state_next = STATE_ADDRESS;
        end else if (data_in_ready && !data_in_valid_reg) begin
          // read
          m_axil_arvalid_next = 1'b1;
          m_axil_rready_next = 1'b1;
          state_next = STATE_READ_1;
        end
      end
      STATE_ADDRESS: begin
        // store address
        data_out_ready_next = 1'b1;

        if (data_out_ready_reg && data_out_valid) begin
          // store pointers
          addr_next[8*count_reg+:8] = data_out;
          count_next = count_reg - 1;
          if (count_reg == 0) begin
            // end of header
            // set initial word offset
            if (ADDR_WIDTH == VALID_ADDR_WIDTH && WORD_PART_ADDR_WIDTH == 0) begin
              count_next = 0;
            end else begin
              count_next = addr_next[ADDR_WIDTH_ADJ-VALID_ADDR_WIDTH-1:0];
            end
            m_axil_wstrb_next = {STRB_WIDTH{1'b0}};
            data_next = {DATA_WIDTH{1'b0}};
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
        // wait for data
        m_axil_rready_next = 1'b1;

        if (m_axil_rready && m_axil_rvalid) begin
          // read cycle complete, store result
          m_axil_rready_next = 1'b0;
          data_next = m_axil_rdata;
          addr_next = addr_reg + (1 << (ADDR_WIDTH - VALID_ADDR_WIDTH + WORD_PART_ADDR_WIDTH));
          state_next = STATE_READ_2;
        end else begin
          state_next = STATE_READ_1;
        end
      end
      STATE_READ_2: begin
        // send data
        if (data_out_valid || !bus_addressed) begin
          // no longer addressed or now addressed for write, return to idle
          state_next = STATE_IDLE;
        end else if (data_in_ready && !data_in_valid_reg) begin
          // transfer word and update pointers
          data_in_next = data_reg[8*count_reg+:8];
          data_in_valid_next = 1'b1;
          count_next = count_reg + 1;
          if (count_reg == (STRB_WIDTH * WORD_SIZE / 8) - 1) begin
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

        if (data_out_ready_reg && data_out_valid) begin
          // store word
          data_next[8*count_reg+:8] = data_out;
          count_next = count_reg + 1;
          m_axil_wstrb_next[count_reg>>((WORD_SIZE/8)-1)] = 1'b1;
          if (count_reg == (STRB_WIDTH * WORD_SIZE / 8) - 1 || data_out_last) begin
            // have full word or at end of block, start write operation
            count_next = 0;
            m_axil_awvalid_next = 1'b1;
            m_axil_wvalid_next = 1'b1;
            m_axil_bready_next = 1'b1;
            state_next = STATE_WRITE_2;
          end else begin
            state_next = STATE_WRITE_1;
          end
        end else begin
          state_next = STATE_WRITE_1;
        end
      end
      STATE_WRITE_2: begin
        // wait for write completion
        m_axil_bready_next = 1'b1;

        if (m_axil_bready && m_axil_bvalid) begin
          // end of write operation
          data_next = {DATA_WIDTH{1'b0}};
          addr_next = addr_reg + (1 << (ADDR_WIDTH - VALID_ADDR_WIDTH + WORD_PART_ADDR_WIDTH));
          m_axil_bready_next = 1'b0;
          m_axil_wstrb_next = {STRB_WIDTH{1'b0}};
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

    m_axil_awvalid_reg <= m_axil_awvalid_next;
    m_axil_wstrb_reg <= m_axil_wstrb_next;
    m_axil_wvalid_reg <= m_axil_wvalid_next;
    m_axil_bready_reg <= m_axil_bready_next;
    m_axil_arvalid_reg <= m_axil_arvalid_next;
    m_axil_rready_reg <= m_axil_rready_next;

    busy_reg <= state_next != STATE_IDLE;

    data_in_reg <= data_in_next;
    data_in_valid_reg <= data_in_valid_next;

    data_out_ready_reg <= data_out_ready_next;

    if (rst) begin
      state_reg <= STATE_IDLE;
      data_in_valid_reg <= 1'b0;
      data_out_ready_reg <= 1'b0;
      m_axil_awvalid_reg <= 1'b0;
      m_axil_wvalid_reg <= 1'b0;
      m_axil_bready_reg <= 1'b0;
      m_axil_arvalid_reg <= 1'b0;
      m_axil_rready_reg <= 1'b0;
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
