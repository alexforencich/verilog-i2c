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
 * I2C master wishbone slave wrapper (16 bit)
 */
module i2c_master_wbs_16 #(
    parameter DEFAULT_PRESCALE = 1,
    parameter FIXED_PRESCALE = 0,
    parameter CMD_FIFO = 1,
    parameter CMD_FIFO_DEPTH = 32,
    parameter WRITE_FIFO = 1,
    parameter WRITE_FIFO_DEPTH = 32,
    parameter READ_FIFO = 1,
    parameter READ_FIFO_DEPTH = 32
) (
    input wire clk,
    input wire rst,

    /*
     * Host interface
     */
    input  wire [ 2:0] wbs_adr_i,  // ADR_I() address
    input  wire [15:0] wbs_dat_i,  // DAT_I() data in
    output wire [15:0] wbs_dat_o,  // DAT_O() data out
    input  wire        wbs_we_i,   // WE_I write enable input
    input  wire [ 1:0] wbs_sel_i,  // SEL_I() select input
    input  wire        wbs_stb_i,  // STB_I strobe input
    output wire        wbs_ack_o,  // ACK_O acknowledge output
    input  wire        wbs_cyc_i,  // CYC_I cycle input

    /*
     * I2C interface
     */
    input  wire i2c_scl_i,
    output wire i2c_scl_o,
    output wire i2c_scl_t,
    input  wire i2c_sda_i,
    output wire i2c_sda_o,
    output wire i2c_sda_t
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

Registers:

| Addr  | Name          |
|-------|---------------|
| 0x00  | Status        |
| 0x02  | Command       |
| 0x04  | Data          |
| 0x06  | Prescale      |

Status register:

| Addr  | Name          |   Bit 15  |   Bit 14  |   Bit 13  |   Bit 12  |   Bit 11  |   Bit 10  |   Bit 9   |   Bit 8   |
|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0x00  | Status        |  rd_full  | rd_empty  |  wr_ovf   |  wr_full  | wr_empty  |  cmd_ovf  | cmd_full  | cmd_empty |

| Addr  | Name          |   Bit 7   |   Bit 6   |   Bit 5   |   Bit 4   |   Bit 3   |   Bit 2   |   Bit 1   |   Bit 0   |
|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0x00  | Status        |     -     |     -     |     -     |     -     | miss_ack  |  bus_act  | bus_cont  |   busy    |

busy: high when module is performing an I2C operation
bus_cont: high when module has control of active bus
bus_act: high when bus is active
miss_ack: set high when an ACK pulse from a slave device is not seen; write 1 to clear
cmd_empty: command FIFO empty
cmd_full: command FIFO full
cmd_ovf: command FIFO overflow; write 1 to clear
wr_empty: write data FIFO empty
wr_full: write data FIFO full
wr_ovf: write data FIFO overflow; write 1 to clear
rd_empty: read data FIFO is empty
rd_full: read data FIFO is full

Command register:

| Addr  | Name          |   Bit 15  |   Bit 14  |   Bit 13  |   Bit 12  |   Bit 11  |   Bit 10  |   Bit 9   |   Bit 8   |
|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0x02  | Command       |     -     |     -     |     -     | cmd_stop  | cmd_wr_m  | cmd_write | cmd_read  | cmd_start |

| Addr  | Name          |   Bit 7   |   Bit 6   |   Bit 5   |   Bit 4   |   Bit 3   |   Bit 2   |   Bit 1   |   Bit 0   |
|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0x02  | Command       |     -     |                               cmd_address[6:0]                                    |

cmd_address: I2C address for command
cmd_start: set high to issue I2C start, write to push on command FIFO
cmd_read: set high to start read, write to push on command FIFO
cmd_write: set high to start write, write to push on command FIFO
cmd_write_multiple: set high to start block write, write to push on command FIFO
cmd_stop: set high to issue I2C stop, write to push on command FIFO

Setting more than one command bit is allowed.  Start or repeated start
will be issued first, followed by read or write, followed by stop.  Note
that setting read and write at the same time is not allowed, this will
result in the command being ignored.  

Data register:

| Addr  | Name          |   Bit 15  |   Bit 14  |   Bit 13  |   Bit 12  |   Bit 11  |   Bit 10  |   Bit 9   |   Bit 8   |
|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0x04  | Data          |     -     |     -     |     -     |     -     |     -     |     -     | data_last | data_valid|

| Addr  | Name          |   Bit 7   |   Bit 6   |   Bit 5   |   Bit 4   |   Bit 3   |   Bit 2   |   Bit 1   |   Bit 0   |
|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0x04  | Data          |                                           data[7:0]                                           |

data: I2C data, write to push on write data FIFO, read to pull from read data FIFO
data_valid: indicates valid read data, must be accessed with atomic 16 bit reads and writes
data_last: indicate last byte of block write (write_multiple), must be accessed with atomic 16 bit reads and writes

Prescale register:

| Addr  | Name          |   Bit 15  |   Bit 14  |   Bit 13  |   Bit 12  |   Bit 11  |   Bit 10  |   Bit 9   |   Bit 8   |
|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0x06  | Prescale      |                                         prescale[15:8]                                        |

| Addr  | Name          |   Bit 7   |   Bit 6   |   Bit 5   |   Bit 4   |   Bit 3   |   Bit 2   |   Bit 1   |   Bit 0   |
|-------|---------------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| 0x06  | Prescale      |                                         prescale[7:0]                                         |

prescale: set prescale value

set prescale to 1/4 of the minimum clock period in units of input clk cycles

prescale = Fclk / (FI2Cclk * 4)

Commands:

read
    read data byte
    set start to force generation of a start condition
    start is implied when bus is inactive or active with write or different address
    set stop to issue a stop condition after reading current byte
    if stop is set with read command, then data_out_last will be set

write
    write data byte
    set start to force generation of a start condition
    start is implied when bus is inactive or active with read or different address
    set stop to issue a stop condition after writing current byte

write multiple
    write multiple data bytes (until data_in_last)
    set start to force generation of a start condition
    start is implied when bus is inactive or active with read or different address
    set stop to issue a stop condition after writing block

stop
    issue stop condition if bus is active

Status:

busy
    module is communicating over the bus

bus_control
    module has control of bus in active state

bus_active
    bus is active, not necessarily controlled by this module

missed_ack
    strobed when a slave ack is missed

Parameters:

prescale
    set prescale to 1/4 of the minimum clock period in units
    of input clk cycles (prescale = Fclk / (FI2Cclk * 4))

stop_on_idle
    automatically issue stop when command input is not valid

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

  reg [15:0] wbs_dat_o_reg = 16'd0, wbs_dat_o_next;
  reg wbs_ack_o_reg = 1'b0, wbs_ack_o_next;

  reg [6:0] cmd_address_reg = 7'd0, cmd_address_next;
  reg cmd_start_reg = 1'b0, cmd_start_next;
  reg cmd_read_reg = 1'b0, cmd_read_next;
  reg cmd_write_reg = 1'b0, cmd_write_next;
  reg cmd_write_multiple_reg = 1'b0, cmd_write_multiple_next;
  reg cmd_stop_reg = 1'b0, cmd_stop_next;
  reg cmd_valid_reg = 1'b0, cmd_valid_next;
  wire cmd_ready;

  reg [7:0] data_in_reg = 8'd0, data_in_next;
  reg data_in_valid_reg = 1'b0, data_in_valid_next;
  wire data_in_ready;
  reg data_in_last_reg = 1'b0, data_in_last_next;

  wire [7:0] data_out;
  wire data_out_valid;
  reg data_out_ready_reg = 1'b0, data_out_ready_next;
  wire data_out_last;

  reg [15:0] prescale_reg = DEFAULT_PRESCALE, prescale_next;

  reg missed_ack_reg = 1'b0, missed_ack_next;

  assign wbs_dat_o = wbs_dat_o_reg;
  assign wbs_ack_o = wbs_ack_o_reg;

  wire [6:0] cmd_address_int;
  wire cmd_start_int;
  wire cmd_read_int;
  wire cmd_write_int;
  wire cmd_write_multiple_int;
  wire cmd_stop_int;
  wire cmd_valid_int;
  wire cmd_ready_int;

  wire [7:0] data_in_int;
  wire data_in_valid_int;
  wire data_in_ready_int;
  wire data_in_last_int;

  wire [7:0] data_out_int;
  wire data_out_valid_int;
  wire data_out_ready_int;
  wire data_out_last_int;

  wire busy_int;
  wire bus_control_int;
  wire bus_active_int;
  wire missed_ack_int;

  wire cmd_fifo_empty = ~cmd_valid_int;
  wire cmd_fifo_full = ~cmd_ready;
  wire write_fifo_empty = ~data_in_valid_int;
  wire write_fifo_full = ~data_in_ready;
  wire read_fifo_empty = ~data_out_valid;
  wire read_fifo_full = ~data_out_ready_int;

  reg cmd_fifo_overflow_reg = 1'b0, cmd_fifo_overflow_next;
  reg write_fifo_overflow_reg = 1'b0, write_fifo_overflow_next;

  generate

    if (CMD_FIFO) begin
      axis_fifo #(
          .DEPTH(CMD_FIFO_DEPTH),
          .DATA_WIDTH(7 + 5),
          .KEEP_ENABLE(0),
          .LAST_ENABLE(0),
          .ID_ENABLE(0),
          .DEST_ENABLE(0),
          .USER_ENABLE(0),
          .FRAME_FIFO(0)
      ) cmd_fifo_inst (
          .clk(clk),
          .rst(rst),
          // AXI input
          .s_axis_tdata({
            cmd_address_reg,
            cmd_start_reg,
            cmd_read_reg,
            cmd_write_reg,
            cmd_write_multiple_reg,
            cmd_stop_reg
          }),
          .s_axis_tkeep(0),
          .s_axis_tvalid(cmd_valid_reg),
          .s_axis_tready(cmd_ready),
          .s_axis_tlast(1'b0),
          .s_axis_tid(0),
          .s_axis_tdest(0),
          .s_axis_tuser(1'b0),
          // AXI output
          .m_axis_tdata({
            cmd_address_int,
            cmd_start_int,
            cmd_read_int,
            cmd_write_int,
            cmd_write_multiple_int,
            cmd_stop_int
          }),
          .m_axis_tkeep(),
          .m_axis_tvalid(cmd_valid_int),
          .m_axis_tready(cmd_ready_int),
          .m_axis_tlast(),
          .m_axis_tid(),
          .m_axis_tdest(),
          .m_axis_tuser()
      );
    end else begin
      assign cmd_address_int = cmd_address_reg;
      assign cmd_start_int = cmd_start_reg;
      assign cmd_read_int = cmd_read_reg;
      assign cmd_write_int = cmd_write_reg;
      assign cmd_write_multiple_int = cmd_write_multiple_reg;
      assign cmd_stop_int = cmd_stop_reg;
      assign cmd_valid_int = cmd_valid_reg;
      assign cmd_ready = cmd_ready_int;
    end

    if (WRITE_FIFO) begin
      axis_fifo #(
          .DEPTH(WRITE_FIFO_DEPTH),
          .DATA_WIDTH(8),
          .KEEP_ENABLE(0),
          .LAST_ENABLE(1),
          .ID_ENABLE(0),
          .DEST_ENABLE(0),
          .USER_ENABLE(0),
          .FRAME_FIFO(0)
      ) write_fifo_inst (
          .clk(clk),
          .rst(rst),
          // AXI input
          .s_axis_tdata(data_in_reg),
          .s_axis_tkeep(0),
          .s_axis_tvalid(data_in_valid_reg),
          .s_axis_tready(data_in_ready),
          .s_axis_tlast(data_in_last_reg),
          .s_axis_tid(0),
          .s_axis_tdest(0),
          .s_axis_tuser(1'b0),
          // AXI output
          .m_axis_tdata(data_in_int),
          .m_axis_tkeep(),
          .m_axis_tvalid(data_in_valid_int),
          .m_axis_tready(data_in_ready_int),
          .m_axis_tlast(data_in_last_int),
          .m_axis_tid(),
          .m_axis_tdest(),
          .m_axis_tuser()
      );
    end else begin
      assign data_in_int   = data_in_reg;
      assign data_in_valid = data_in_valid_reg;
      assign data_in_ready = data_in_ready_int;
      assign data_in_last  = data_in_last_reg;
    end

    if (READ_FIFO) begin
      axis_fifo #(
          .DEPTH(READ_FIFO_DEPTH),
          .DATA_WIDTH(8),
          .KEEP_ENABLE(0),
          .LAST_ENABLE(1),
          .ID_ENABLE(0),
          .DEST_ENABLE(0),
          .USER_ENABLE(0),
          .FRAME_FIFO(0)
      ) read_fifo_inst (
          .clk(clk),
          .rst(rst),
          // AXI input
          .s_axis_tdata(data_out_int),
          .s_axis_tkeep(0),
          .s_axis_tvalid(data_out_valid_int),
          .s_axis_tready(data_out_ready_int),
          .s_axis_tlast(data_out_last_int),
          .s_axis_tid(0),
          .s_axis_tdest(0),
          .s_axis_tuser(0),
          // AXI output
          .m_axis_tdata(data_out),
          .m_axis_tkeep(),
          .m_axis_tvalid(data_out_valid),
          .m_axis_tready(data_out_ready_reg),
          .m_axis_tlast(data_out_last),
          .m_axis_tid(),
          .m_axis_tdest(),
          .m_axis_tuser()
      );
    end else begin
      assign data_out = data_out_int;
      assign data_out_valid = data_out_valid_int;
      assign data_out_ready_int = data_out_ready_reg;
      assign data_out_last = data_out_last_int;
    end

  endgenerate

  always @* begin
    wbs_dat_o_next = 8'd0;
    wbs_ack_o_next = 1'b0;

    cmd_address_next = cmd_address_reg;
    cmd_start_next = cmd_start_reg;
    cmd_read_next = cmd_read_reg;
    cmd_write_next = cmd_write_reg;
    cmd_write_multiple_next = cmd_write_multiple_reg;
    cmd_stop_next = cmd_stop_reg;
    cmd_valid_next = cmd_valid_reg & ~cmd_ready;

    data_in_next = data_in_reg;
    data_in_valid_next = data_in_valid_reg & ~data_in_ready;
    data_in_last_next = data_in_last_reg;

    data_out_ready_next = 1'b0;

    prescale_next = prescale_reg;

    missed_ack_next = missed_ack_reg | missed_ack_int;

    cmd_fifo_overflow_next = cmd_fifo_overflow_reg;
    write_fifo_overflow_next = write_fifo_overflow_reg;

    if (wbs_cyc_i & wbs_stb_i) begin
      // bus cycle
      if (wbs_we_i) begin
        // write cycle
        case (wbs_adr_i)
          3'h0: begin
            // status register
            if (wbs_sel_i[0]) begin
              if (wbs_dat_i[3]) begin
                missed_ack_next = missed_ack_int;
              end
            end
            if (wbs_sel_i[1]) begin
              if (wbs_dat_i[10]) begin
                cmd_fifo_overflow_next = 1'b0;
              end
              if (wbs_dat_i[13]) begin
                write_fifo_overflow_next = 1'b0;
              end
            end
          end
          3'h2: begin
            // command
            if (wbs_sel_i[0]) begin
              cmd_address_next = wbs_dat_i[6:0];
            end
            if (wbs_sel_i[1]) begin
              cmd_start_next = wbs_dat_i[8];
              cmd_read_next = wbs_dat_i[9];
              cmd_write_next = wbs_dat_i[10];
              cmd_write_multiple_next = wbs_dat_i[11];
              cmd_stop_next = wbs_dat_i[12];
              cmd_valid_next = ~wbs_ack_o_reg & (cmd_start_next | cmd_read_next | cmd_write_next | cmd_write_multiple_next | cmd_stop_next);

              cmd_fifo_overflow_next = cmd_fifo_overflow_next | (cmd_valid_next & ~cmd_ready);
            end
          end
          3'h4: begin
            // data
            if (wbs_sel_i[0]) begin
              data_in_next = wbs_dat_i[7:0];

              if (wbs_sel_i[1]) begin
                // only valid with atomic 16 bit write
                data_in_last_next = wbs_dat_i[9];
              end else begin
                data_in_last_next = 1'b0;
              end

              data_in_valid_next = ~wbs_ack_o_reg;

              write_fifo_overflow_next = write_fifo_overflow_next | ~data_in_ready;
            end
          end
          3'h6: begin
            // prescale
            if (!FIXED_PRESCALE && wbs_sel_i[0]) begin
              prescale_next[7:0] = wbs_dat_i[7:0];
            end
            if (!FIXED_PRESCALE && wbs_sel_i[1]) begin
              prescale_next[15:0] = wbs_dat_i[15:0];
            end
          end
        endcase
        wbs_ack_o_next = ~wbs_ack_o_reg;
      end else begin
        // read cycle
        case (wbs_adr_i)
          3'h0: begin
            // status
            wbs_dat_o_next[0]  = busy_int;
            wbs_dat_o_next[1]  = bus_control_int;
            wbs_dat_o_next[2]  = bus_active_int;
            wbs_dat_o_next[3]  = missed_ack_reg;
            wbs_dat_o_next[4]  = 1'b0;
            wbs_dat_o_next[5]  = 1'b0;
            wbs_dat_o_next[6]  = 1'b0;
            wbs_dat_o_next[7]  = 1'b0;
            wbs_dat_o_next[8]  = cmd_fifo_empty;
            wbs_dat_o_next[9]  = cmd_fifo_full;
            wbs_dat_o_next[10] = cmd_fifo_overflow_reg;
            wbs_dat_o_next[11] = write_fifo_empty;
            wbs_dat_o_next[12] = write_fifo_full;
            wbs_dat_o_next[13] = write_fifo_overflow_reg;
            wbs_dat_o_next[14] = read_fifo_empty;
            wbs_dat_o_next[15] = read_fifo_full;
          end
          3'h2: begin
            // command
            wbs_dat_o_next[6:0] = cmd_address_reg;
            wbs_dat_o_next[7]   = 1'b0;
            wbs_dat_o_next[8]   = cmd_start_reg;
            wbs_dat_o_next[9]   = cmd_read_reg;
            wbs_dat_o_next[10]  = cmd_write_reg;
            wbs_dat_o_next[11]  = cmd_write_multiple_reg;
            wbs_dat_o_next[12]  = cmd_stop_reg;
            wbs_dat_o_next[13]  = 1'b0;
            wbs_dat_o_next[14]  = 1'b0;
            wbs_dat_o_next[15]  = 1'b0;
          end
          3'h4: begin
            // data
            wbs_dat_o_next[7:0] = data_out;
            wbs_dat_o_next[8] = data_out_valid;
            wbs_dat_o_next[9] = data_out_last;
            wbs_dat_o_next[15:10] = 6'd0;

            if (wbs_sel_i[0]) begin
              data_out_ready_next = !wbs_ack_o_reg && data_out_valid;
            end
          end
          3'h6: begin
            // prescale
            wbs_dat_o_next = prescale_reg;
          end
        endcase
        wbs_ack_o_next = ~wbs_ack_o_reg;
      end
    end
  end

  always @(posedge clk) begin
    wbs_dat_o_reg <= wbs_dat_o_next;
    wbs_ack_o_reg <= wbs_ack_o_next;

    cmd_address_reg <= cmd_address_next;
    cmd_start_reg <= cmd_start_next;
    cmd_read_reg <= cmd_read_next;
    cmd_write_reg <= cmd_write_next;
    cmd_write_multiple_reg <= cmd_write_multiple_next;
    cmd_stop_reg <= cmd_stop_next;
    cmd_valid_reg <= cmd_valid_next;

    data_in_reg <= data_in_next;
    data_in_valid_reg <= data_in_valid_next;
    data_in_last_reg <= data_in_last_next;

    data_out_ready_reg <= data_out_ready_next;

    prescale_reg <= prescale_next;

    missed_ack_reg <= missed_ack_next;

    cmd_fifo_overflow_reg <= cmd_fifo_overflow_next;
    write_fifo_overflow_reg <= write_fifo_overflow_next;

    if (rst) begin
      wbs_ack_o_reg <= 1'b0;
      cmd_valid_reg <= 1'b0;
      data_in_valid_reg <= 1'b0;
      data_out_ready_reg <= 1'b0;
      prescale_reg <= DEFAULT_PRESCALE;
      missed_ack_reg <= 1'b0;
      cmd_fifo_overflow_reg <= 0;
      write_fifo_overflow_reg <= 0;
    end
  end

  i2c_master i2c_master_inst (
      .clk(clk),
      .rst(rst),

      // Host interface
      .s_axis_cmd_address(cmd_address_int),
      .s_axis_cmd_start(cmd_start_int),
      .s_axis_cmd_read(cmd_read_int),
      .s_axis_cmd_write(cmd_write_int),
      .s_axis_cmd_write_multiple(cmd_write_multiple_int),
      .s_axis_cmd_stop(cmd_stop_int),
      .s_axis_cmd_valid(cmd_valid_int),
      .s_axis_cmd_ready(cmd_ready_int),

      .s_axis_data_tdata (data_in_int),
      .s_axis_data_tvalid(data_in_valid_int),
      .s_axis_data_tready(data_in_ready_int),
      .s_axis_data_tlast (data_in_last_int),

      .m_axis_data_tdata (data_out_int),
      .m_axis_data_tvalid(data_out_valid_int),
      .m_axis_data_tready(data_out_ready_int),
      .m_axis_data_tlast (data_out_last_int),

      // I2C interface
      .scl_i(i2c_scl_i),
      .scl_o(i2c_scl_o),
      .scl_t(i2c_scl_t),
      .sda_i(i2c_sda_i),
      .sda_o(i2c_sda_o),
      .sda_t(i2c_sda_t),

      // Status
      .busy(busy_int),
      .bus_control(bus_control_int),
      .bus_active(bus_active_int),
      .missed_ack(missed_ack_int),

      // Configuration
      .prescale(prescale_reg),
      .stop_on_idle(1'b0)
  );

endmodule
