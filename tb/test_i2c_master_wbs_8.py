#!/usr/bin/env python
"""

Copyright (c) 2016-2017 Alex Forencich

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

"""

from myhdl import *
import os

import i2c
import wb

module = 'i2c_master_wbs_8'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/i2c_master.v")
srcs.append("../rtl/axis_fifo.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    DEFAULT_PRESCALE = 1
    FIXED_PRESCALE = 0
    CMD_FIFO = 1
    CMD_FIFO_ADDR_WIDTH = 5
    WRITE_FIFO = 1
    WRITE_FIFO_ADDR_WIDTH = 5
    READ_FIFO = 1
    READ_FIFO_ADDR_WIDTH = 5

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    wbs_adr_i = Signal(intbv(0)[3:])
    wbs_dat_i = Signal(intbv(0)[8:])
    wbs_we_i = Signal(bool(0))
    wbs_stb_i = Signal(bool(0))
    wbs_cyc_i = Signal(bool(0))
    i2c_scl_i = Signal(bool(1))
    i2c_sda_i = Signal(bool(1))

    s1_scl_i = Signal(bool(1))
    s1_sda_i = Signal(bool(1))

    s2_scl_i = Signal(bool(1))
    s2_sda_i = Signal(bool(1))

    # Outputs
    wbs_dat_o = Signal(intbv(0)[8:])
    wbs_ack_o = Signal(bool(0))
    i2c_scl_o = Signal(bool(1))
    i2c_scl_t = Signal(bool(1))
    i2c_sda_o = Signal(bool(1))
    i2c_sda_t = Signal(bool(1))

    s1_scl_o = Signal(bool(1))
    s1_scl_t = Signal(bool(1))
    s1_sda_o = Signal(bool(1))
    s1_sda_t = Signal(bool(1))

    s2_scl_o = Signal(bool(1))
    s2_scl_t = Signal(bool(1))
    s2_sda_o = Signal(bool(1))
    s2_sda_t = Signal(bool(1))

    # WB master
    wbm_inst = wb.WBMaster()

    wbm_logic = wbm_inst.create_logic(
        clk,
        adr_o=wbs_adr_i,
        dat_i=wbs_dat_o,
        dat_o=wbs_dat_i,
        we_o=wbs_we_i,
        stb_o=wbs_stb_i,
        ack_i=wbs_ack_o,
        cyc_o=wbs_cyc_i,
        name='master'
    )

    # I2C memory model 1
    i2c_mem_inst1 = i2c.I2CMem(1024)

    i2c_mem_logic1 = i2c_mem_inst1.create_logic(
        scl_i=s1_scl_i,
        scl_o=s1_scl_o,
        scl_t=s1_scl_t,
        sda_i=s1_sda_i,
        sda_o=s1_sda_o,
        sda_t=s1_sda_t,
        abw=2,
        address=0x50,
        latency=0,
        name='slave1'
    )

    # I2C memory model 2
    i2c_mem_inst2 = i2c.I2CMem(1024)

    i2c_mem_logic2 = i2c_mem_inst2.create_logic(
        scl_i=s2_scl_i,
        scl_o=s2_scl_o,
        scl_t=s2_scl_t,
        sda_i=s2_sda_i,
        sda_o=s2_sda_o,
        sda_t=s2_sda_t,
        abw=2,
        address=0x51,
        latency=1000,
        name='slave2'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")
    
    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,

        wbs_adr_i=wbs_adr_i,
        wbs_dat_i=wbs_dat_i,
        wbs_dat_o=wbs_dat_o,
        wbs_we_i=wbs_we_i,
        wbs_stb_i=wbs_stb_i,
        wbs_ack_o=wbs_ack_o,
        wbs_cyc_i=wbs_cyc_i,

        i2c_scl_i=i2c_scl_i,
        i2c_scl_o=i2c_scl_o,
        i2c_scl_t=i2c_scl_t,
        i2c_sda_i=i2c_sda_i,
        i2c_sda_o=i2c_sda_o,
        i2c_sda_t=i2c_sda_t
    )

    @always_comb
    def bus():
        # emulate I2C wired AND
        i2c_scl_i.next = i2c_scl_o & s1_scl_o & s2_scl_o;
        i2c_sda_i.next = i2c_sda_o & s1_sda_o & s2_sda_o;

        s1_scl_i.next = i2c_scl_o & s1_scl_o & s2_scl_o;
        s1_sda_i.next = i2c_sda_o & s1_sda_o & s2_sda_o;

        s2_scl_i.next = i2c_scl_o & s1_scl_o & s2_scl_o;
        s2_sda_i.next = i2c_sda_o & s1_sda_o & s2_sda_o;

    @always(delay(4))
    def clkgen():
        clk.next = not clk

    @instance
    def check():
        yield delay(100)
        yield clk.posedge
        rst.next = 1
        yield clk.posedge
        rst.next = 0
        yield clk.posedge
        yield delay(100)
        yield clk.posedge

        # testbench stimulus

        yield clk.posedge
        print("test 1: write")
        current_test.next = 1

        wbm_inst.init_write(2, b'\x50\x04\x00')
        wbm_inst.init_write(3, b'\x04\x04')
        wbm_inst.init_write(3, b'\x04\x11')
        wbm_inst.init_write(3, b'\x04\x22')
        wbm_inst.init_write(3, b'\x04\x33')
        wbm_inst.init_write(3, b'\x14\x44')

        yield wbm_inst.wait()
        yield clk.posedge

        while True:
            wbm_inst.init_read(0, 1)
            yield wbm_inst.wait()
            data = wbm_inst.get_read_data()
            if data[1][0] & 0x03 == 0:
                break

        data = i2c_mem_inst1.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert i2c_mem_inst1.read_mem(4,4) == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 2: read")
        current_test.next = 2

        wbm_inst.init_write(2, b'\x50\x04\x00')
        wbm_inst.init_write(3, b'\x04\x04')
        wbm_inst.init_write(3, b'\x03')
        wbm_inst.init_write(3, b'\x02')
        wbm_inst.init_write(3, b'\x02')
        wbm_inst.init_write(3, b'\x12')

        yield wbm_inst.wait()
        yield clk.posedge

        while True:
            wbm_inst.init_read(0, 1)
            yield wbm_inst.wait()
            data = wbm_inst.get_read_data()
            if data[1][0] & 0x03 == 0:
                break

        wbm_inst.init_read(4, 1)
        wbm_inst.init_read(4, 1)
        wbm_inst.init_read(4, 1)
        wbm_inst.init_read(4, 1)

        yield wbm_inst.wait()
        yield clk.posedge

        data = wbm_inst.get_read_data()
        assert data[1] == b'\x11'

        data = wbm_inst.get_read_data()
        assert data[1] == b'\x22'

        data = wbm_inst.get_read_data()
        assert data[1] == b'\x33'

        data = wbm_inst.get_read_data()
        assert data[1] == b'\x44'

        yield delay(100)

        yield clk.posedge
        print("test 3: write to slave 2")
        current_test.next = 3

        wbm_inst.init_write(2, b'\x51\x04\x00')
        wbm_inst.init_write(3, b'\x04\x04')
        wbm_inst.init_write(3, b'\x04\x44')
        wbm_inst.init_write(3, b'\x04\x33')
        wbm_inst.init_write(3, b'\x04\x22')
        wbm_inst.init_write(3, b'\x14\x11')

        yield wbm_inst.wait()
        yield clk.posedge

        while True:
            wbm_inst.init_read(0, 1)
            yield wbm_inst.wait()
            data = wbm_inst.get_read_data()
            if data[1][0] & 0x03 == 0:
                break

        data = i2c_mem_inst2.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert i2c_mem_inst2.read_mem(4,4) == b'\x44\x33\x22\x11'

        yield delay(100)

        yield clk.posedge
        print("test 4: read from slave 2")
        current_test.next = 4

        wbm_inst.init_write(2, b'\x51\x04\x00')
        wbm_inst.init_write(3, b'\x04\x04')
        wbm_inst.init_write(3, b'\x03')
        wbm_inst.init_write(3, b'\x02')
        wbm_inst.init_write(3, b'\x02')
        wbm_inst.init_write(3, b'\x12')

        yield wbm_inst.wait()
        yield clk.posedge

        while True:
            wbm_inst.init_read(0, 1)
            yield wbm_inst.wait()
            data = wbm_inst.get_read_data()
            if data[1][0] & 0x03 == 0:
                break

        wbm_inst.init_read(4, 1)
        wbm_inst.init_read(4, 1)
        wbm_inst.init_read(4, 1)
        wbm_inst.init_read(4, 1)

        yield wbm_inst.wait()
        yield clk.posedge

        data = wbm_inst.get_read_data()
        assert data[1] == b'\x44'

        data = wbm_inst.get_read_data()
        assert data[1] == b'\x33'

        data = wbm_inst.get_read_data()
        assert data[1] == b'\x22'

        data = wbm_inst.get_read_data()
        assert data[1] == b'\x11'

        yield delay(100)

        yield clk.posedge
        print("test 5: write to nonexistent device")
        current_test.next = 5

        wbm_inst.init_write(2, b'\x52\x04\x00')
        wbm_inst.init_write(3, b'\x04\x04')
        wbm_inst.init_write(3, b'\x04\xde')
        wbm_inst.init_write(3, b'\x04\xad')
        wbm_inst.init_write(3, b'\x04\xbe')
        wbm_inst.init_write(3, b'\x14\xef')

        yield wbm_inst.wait()
        yield clk.posedge

        got_missed_ack = False

        while True:
            wbm_inst.init_read(0, 1)
            yield wbm_inst.wait()
            data = wbm_inst.get_read_data()
            if data[1][0] & 0x08:
                got_missed_ack = True
            if data[1][0] & 0x03 == 0:
                break

        assert got_missed_ack

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
