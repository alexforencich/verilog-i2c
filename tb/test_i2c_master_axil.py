#!/usr/bin/env python
"""

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

"""

from myhdl import *
import os

import i2c
import axil

module = 'i2c_master_axil'
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

    s_axil_awaddr = Signal(intbv(0)[4:])
    s_axil_awprot = Signal(intbv(0)[3:])
    s_axil_awvalid = Signal(bool(0))
    s_axil_wdata = Signal(intbv(0)[32:])
    s_axil_wstrb = Signal(intbv(0)[4:])
    s_axil_wvalid = Signal(bool(0))
    s_axil_bready = Signal(bool(0))
    s_axil_araddr = Signal(intbv(0)[4:])
    s_axil_arprot = Signal(intbv(0)[3:])
    s_axil_arvalid = Signal(bool(0))
    s_axil_rready = Signal(bool(0))
    i2c_scl_i = Signal(bool(1))
    i2c_sda_i = Signal(bool(1))

    s1_scl_i = Signal(bool(1))
    s1_sda_i = Signal(bool(1))

    s2_scl_i = Signal(bool(1))
    s2_sda_i = Signal(bool(1))

    # Outputs
    s_axil_awready = Signal(bool(0))
    s_axil_wready = Signal(bool(0))
    s_axil_bresp = Signal(intbv(0)[2:])
    s_axil_bvalid = Signal(bool(0))
    s_axil_arready = Signal(bool(0))
    s_axil_rdata = Signal(intbv(0)[32:])
    s_axil_rresp = Signal(intbv(0)[2:])
    s_axil_rvalid = Signal(bool(0))
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

    # AXI4-Lite master
    axil_master_inst = axil.AXILiteMaster()
    axil_master_pause = Signal(bool(False))

    axil_master_logic = axil_master_inst.create_logic(
        clk,
        rst,
        m_axil_awaddr=s_axil_awaddr,
        m_axil_awprot=s_axil_awprot,
        m_axil_awvalid=s_axil_awvalid,
        m_axil_awready=s_axil_awready,
        m_axil_wdata=s_axil_wdata,
        m_axil_wstrb=s_axil_wstrb,
        m_axil_wvalid=s_axil_wvalid,
        m_axil_wready=s_axil_wready,
        m_axil_bresp=s_axil_bresp,
        m_axil_bvalid=s_axil_bvalid,
        m_axil_bready=s_axil_bready,
        m_axil_araddr=s_axil_araddr,
        m_axil_arprot=s_axil_arprot,
        m_axil_arvalid=s_axil_arvalid,
        m_axil_arready=s_axil_arready,
        m_axil_rdata=s_axil_rdata,
        m_axil_rresp=s_axil_rresp,
        m_axil_rvalid=s_axil_rvalid,
        m_axil_rready=s_axil_rready,
        pause=axil_master_pause,
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

        s_axil_awaddr=s_axil_awaddr,
        s_axil_awprot=s_axil_awprot,
        s_axil_awvalid=s_axil_awvalid,
        s_axil_awready=s_axil_awready,
        s_axil_wdata=s_axil_wdata,
        s_axil_wstrb=s_axil_wstrb,
        s_axil_wvalid=s_axil_wvalid,
        s_axil_wready=s_axil_wready,
        s_axil_bresp=s_axil_bresp,
        s_axil_bvalid=s_axil_bvalid,
        s_axil_bready=s_axil_bready,
        s_axil_araddr=s_axil_araddr,
        s_axil_arprot=s_axil_arprot,
        s_axil_arvalid=s_axil_arvalid,
        s_axil_arready=s_axil_arready,
        s_axil_rdata=s_axil_rdata,
        s_axil_rresp=s_axil_rresp,
        s_axil_rvalid=s_axil_rvalid,
        s_axil_rready=s_axil_rready,

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
        scl = i2c_scl_o & s1_scl_o & s2_scl_o;
        sda = i2c_sda_o & s1_sda_o & s2_sda_o;

        i2c_scl_i.next = scl;
        i2c_sda_i.next = sda;

        s1_scl_i.next = scl;
        s1_sda_i.next = sda;

        s2_scl_i.next = scl;
        s2_sda_i.next = sda;

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

        axil_master_inst.init_write(4, b'\x50\x04\x00\x00\x00')
        axil_master_inst.init_write(4, b'\x50\x04\x00\x00\x04')
        axil_master_inst.init_write(4, b'\x50\x04\x00\x00\x11')
        axil_master_inst.init_write(4, b'\x50\x04\x00\x00\x22')
        axil_master_inst.init_write(4, b'\x50\x04\x00\x00\x33')
        axil_master_inst.init_write(4, b'\x50\x14\x00\x00\x44')

        yield axil_master_inst.wait()
        yield clk.posedge

        while True:
            axil_master_inst.init_read(0, 1)
            yield axil_master_inst.wait()
            data = axil_master_inst.get_read_data()
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

        axil_master_inst.init_write(4, b'\x50\x04\x00\x00\x00')
        axil_master_inst.init_write(4, b'\x50\x04\x00\x00\x04')
        axil_master_inst.init_write(4, b'\x50\x03')
        axil_master_inst.init_write(4, b'\x50\x02')
        axil_master_inst.init_write(4, b'\x50\x02')
        axil_master_inst.init_write(4, b'\x50\x12')

        yield axil_master_inst.wait()
        yield clk.posedge

        while True:
            axil_master_inst.init_read(0, 1)
            yield axil_master_inst.wait()
            data = axil_master_inst.get_read_data()
            if data[1][0] & 0x03 == 0:
                break

        axil_master_inst.init_read(8, 2)
        axil_master_inst.init_read(8, 2)
        axil_master_inst.init_read(8, 2)
        axil_master_inst.init_read(8, 2)

        yield axil_master_inst.wait()
        yield clk.posedge

        data = axil_master_inst.get_read_data()
        assert data[1] == b'\x11\x01'

        data = axil_master_inst.get_read_data()
        assert data[1] == b'\x22\x01'

        data = axil_master_inst.get_read_data()
        assert data[1] == b'\x33\x01'

        data = axil_master_inst.get_read_data()
        assert data[1] == b'\x44\x03'

        yield delay(100)

        yield clk.posedge
        print("test 3: write to slave 2")
        current_test.next = 3

        axil_master_inst.init_write(4, b'\x51\x08\x00\x00\x00\x00')
        axil_master_inst.init_write(8, b'\x04\x00')
        axil_master_inst.init_write(8, b'\x44\x00')
        axil_master_inst.init_write(8, b'\x33\x00')
        axil_master_inst.init_write(8, b'\x22\x00')
        axil_master_inst.init_write(8, b'\x11\x02')
        axil_master_inst.init_write(4, b'\x51\x10')

        yield axil_master_inst.wait()
        yield clk.posedge

        while True:
            axil_master_inst.init_read(0, 1)
            yield axil_master_inst.wait()
            data = axil_master_inst.get_read_data()
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

        axil_master_inst.init_write(4, b'\x51\x04\x00\x00\x00')
        axil_master_inst.init_write(4, b'\x51\x04\x00\x00\x04')
        axil_master_inst.init_write(4, b'\x51\x03')
        axil_master_inst.init_write(4, b'\x51\x02')
        axil_master_inst.init_write(4, b'\x51\x02')
        axil_master_inst.init_write(4, b'\x51\x12')

        yield axil_master_inst.wait()
        yield clk.posedge

        while True:
            axil_master_inst.init_read(0, 1)
            yield axil_master_inst.wait()
            data = axil_master_inst.get_read_data()
            if data[1][0] & 0x03 == 0:
                break

        axil_master_inst.init_read(8, 2)
        axil_master_inst.init_read(8, 2)
        axil_master_inst.init_read(8, 2)
        axil_master_inst.init_read(8, 2)

        yield axil_master_inst.wait()
        yield clk.posedge

        data = axil_master_inst.get_read_data()
        assert data[1] == b'\x44\x01'

        data = axil_master_inst.get_read_data()
        assert data[1] == b'\x33\x01'

        data = axil_master_inst.get_read_data()
        assert data[1] == b'\x22\x01'

        data = axil_master_inst.get_read_data()
        assert data[1] == b'\x11\x03'

        yield delay(100)

        yield clk.posedge
        print("test 5: write to nonexistent device")
        current_test.next = 5

        axil_master_inst.init_write(4, b'\x52\x04\x00\x00\x00')
        axil_master_inst.init_write(4, b'\x52\x04\x00\x00\x04')
        axil_master_inst.init_write(4, b'\x52\x04\x00\x00\xde')
        axil_master_inst.init_write(4, b'\x52\x04\x00\x00\xad')
        axil_master_inst.init_write(4, b'\x52\x04\x00\x00\xbe')
        axil_master_inst.init_write(4, b'\x52\x14\x00\x00\xef')

        yield axil_master_inst.wait()
        yield clk.posedge

        got_missed_ack = False

        while True:
            axil_master_inst.init_read(0, 1)
            yield axil_master_inst.wait()
            data = axil_master_inst.get_read_data()
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
