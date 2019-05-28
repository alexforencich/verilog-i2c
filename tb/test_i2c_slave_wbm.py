#!/usr/bin/env python
"""

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

"""

from myhdl import *
import os
import struct

import i2c
import wb

module = 'i2c_slave_wbm'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("../rtl/i2c_slave.v")
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    FILTER_LEN = 4
    WB_DATA_WIDTH = 32
    WB_ADDR_WIDTH = 16
    WB_SELECT_WIDTH = WB_DATA_WIDTH/8

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    i2c_scl_i = Signal(bool(1))
    i2c_sda_i = Signal(bool(1))
    wb_dat_i = Signal(intbv(0)[WB_DATA_WIDTH:])
    wb_ack_i = Signal(bool(0))
    wb_err_i = Signal(bool(0))
    enable = Signal(bool(0))
    device_address = Signal(intbv(0)[7:])

    m_scl_i = Signal(bool(1))
    m_sda_i = Signal(bool(1))

    s2_scl_i = Signal(bool(1))
    s2_sda_i = Signal(bool(1))

    # Outputs
    i2c_scl_o = Signal(bool(1))
    i2c_scl_t = Signal(bool(1))
    i2c_sda_o = Signal(bool(1))
    i2c_sda_t = Signal(bool(1))
    wb_adr_o = Signal(intbv(0)[WB_ADDR_WIDTH:])
    wb_dat_o = Signal(intbv(0)[WB_DATA_WIDTH:])
    wb_we_o = Signal(bool(0))
    wb_sel_o = Signal(intbv(0)[WB_SELECT_WIDTH:])
    wb_stb_o = Signal(bool(0))
    wb_cyc_o = Signal(bool(0))
    busy = Signal(bool(0))
    bus_addressed = Signal(bool(0))
    bus_active = Signal(bool(0))

    m_scl_o = Signal(bool(1))
    m_scl_t = Signal(bool(1))
    m_sda_o = Signal(bool(1))
    m_sda_t = Signal(bool(1))

    s2_scl_o = Signal(bool(1))
    s2_scl_t = Signal(bool(1))
    s2_sda_o = Signal(bool(1))
    s2_sda_t = Signal(bool(1))

    # I2C master
    i2c_master_inst = i2c.I2CMaster()

    i2c_master_logic = i2c_master_inst.create_logic(
        clk,
        rst,
        scl_i=m_scl_i,
        scl_o=m_scl_o,
        scl_t=m_scl_t,
        sda_i=m_sda_i,
        sda_o=m_sda_o,
        sda_t=m_sda_t,
        prescale=4,
        name='master'
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
        latency=0,
        name='slave2'
    )

    # WB RAM model
    wb_ram_inst = wb.WBRam(2**16)

    wb_ram_port0 = wb_ram_inst.create_port(
        clk,
        adr_i=wb_adr_o,
        dat_i=wb_dat_o,
        dat_o=wb_dat_i,
        we_i=wb_we_o,
        sel_i=wb_sel_o,
        stb_i=wb_stb_o,
        ack_o=wb_ack_i,
        cyc_i=wb_cyc_o,
        latency=1,
        asynchronous=False,
        name='port0'
    )

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        i2c_scl_i=i2c_scl_i,
        i2c_scl_o=i2c_scl_o,
        i2c_scl_t=i2c_scl_t,
        i2c_sda_i=i2c_sda_i,
        i2c_sda_o=i2c_sda_o,
        i2c_sda_t=i2c_sda_t,
        wb_adr_o=wb_adr_o,
        wb_dat_i=wb_dat_i,
        wb_dat_o=wb_dat_o,
        wb_we_o=wb_we_o,
        wb_sel_o=wb_sel_o,
        wb_stb_o=wb_stb_o,
        wb_ack_i=wb_ack_i,
        wb_err_i=wb_err_i,
        wb_cyc_o=wb_cyc_o,
        busy=busy,
        bus_addressed=bus_addressed,
        bus_active=bus_active,
        enable=enable,
        device_address=device_address
    )

    @always_comb
    def bus():
        # emulate I2C wired AND
        scl = m_scl_o & i2c_scl_o & s2_scl_o
        sda = m_sda_o & i2c_sda_o & s2_sda_o

        m_scl_i.next = scl;
        m_sda_i.next = sda;

        i2c_scl_i.next = scl
        i2c_sda_i.next = sda

        s2_scl_i.next = scl
        s2_sda_i.next = sda

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

        enable.next = 1
        device_address.next = 0x50

        yield clk.posedge
        print("test 1: write")
        current_test.next = 1

        i2c_master_inst.init_write(0x50, b'\x00\x04'+b'\x11\x22\x33\x44')

        yield i2c_master_inst.wait()
        yield clk.posedge

        while busy:
            yield clk.posedge

        data = wb_ram_inst.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert wb_ram_inst.read_mem(4,4) == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 2: read")
        current_test.next = 2

        i2c_master_inst.init_write(0x50, b'\x00\x04')
        i2c_master_inst.init_read(0x50, 4)

        yield i2c_master_inst.wait()
        yield clk.posedge

        data = i2c_master_inst.get_read_data()
        assert data[0] == 0x50
        assert data[1] == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 3: various writes")
        current_test.next = 3

        for length in range(1,9):
            for offset in range(4):
                i2c_master_inst.init_write(0x50, bytearray(struct.pack('>H', 256*(16*offset+length)+offset)+b'\x11\x22\x33\x44\x55\x66\x77\x88'[0:length]))

                yield i2c_master_inst.wait()
                yield clk.posedge

                while busy:
                    yield clk.posedge

                data = wb_ram_inst.read_mem(256*(16*offset+length), 32)
                for i in range(0, len(data), 16):
                    print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

                assert wb_ram_inst.read_mem(256*(16*offset+length)+offset,length) == b'\x11\x22\x33\x44\x55\x66\x77\x88'[0:length]

        yield delay(100)

        yield clk.posedge
        print("test 4: various reads")
        current_test.next = 4

        for length in range(1,9):
            for offset in range(4):
                i2c_master_inst.init_write(0x50, bytearray(struct.pack('>H', 256*(16*offset+length)+offset)))
                i2c_master_inst.init_read(0x50, length)

                yield i2c_master_inst.wait()
                yield clk.posedge

                data = i2c_master_inst.get_read_data()
                assert data[0] == 0x50
                assert data[1] == b'\x11\x22\x33\x44\x55\x66\x77\x88'[0:length]

        yield delay(100)

        # TODO various reads and writes

        # yield clk.posedge
        # print("test 3: read with delays")
        # current_test.next = 3

        # i2c_master_inst.init_write(0x50, b'\x00\x04')
        # i2c_master_inst.init_read(0x50, 4)

        # data_source.send(b'\x11\x22\x33\x44')

        # data_source_pause.next = True
        # data_sink_pause.next = True

        # yield delay(5000)
        # data_sink_pause.next = False

        # yield delay(2000)
        # data_source_pause.next = False

        # yield i2c_master_inst.wait()
        # yield clk.posedge

        # data = None
        # while not data:
        #     yield clk.posedge
        #     data = data_sink.recv()

        # assert data.data == b'\x00\x04'

        # data = i2c_master_inst.get_read_data()
        # assert data[0] == 0x50
        # assert data[1] == b'\x11\x22\x33\x44'

        # yield delay(100)

        yield clk.posedge
        print("test 4: access slave 2")
        current_test.next = 4

        i2c_master_inst.init_write(0x51, b'\x00\x04'+b'\x11\x22\x33\x44')

        yield i2c_master_inst.wait()
        yield clk.posedge

        data = i2c_mem_inst2.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert i2c_mem_inst2.read_mem(4,4) == b'\x11\x22\x33\x44'

        i2c_master_inst.init_write(0x51, b'\x00\x04')
        i2c_master_inst.init_read(0x51, 4)

        yield i2c_master_inst.wait()
        yield clk.posedge

        data = i2c_master_inst.get_read_data()
        assert data[0] == 0x51
        assert data[1] == b'\x11\x22\x33\x44'

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
