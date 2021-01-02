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

import axis_ep
import i2c

module = 'i2c_slave'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters
    FILTER_LEN = 1

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    release_bus = Signal(bool(0))
    s_axis_data_tdata = Signal(intbv(0)[8:])
    s_axis_data_tvalid = Signal(bool(0))
    s_axis_data_tlast = Signal(bool(0))
    m_axis_data_tready = Signal(bool(0))
    scl_i = Signal(bool(1))
    sda_i = Signal(bool(1))
    enable = Signal(bool(0))
    device_address = Signal(intbv(0)[7:])
    device_address_mask = Signal(intbv(0x7f)[7:])

    m_scl_i = Signal(bool(1))
    m_sda_i = Signal(bool(1))

    s2_scl_i = Signal(bool(1))
    s2_sda_i = Signal(bool(1))

    # Outputs
    s_axis_data_tready = Signal(bool(0))
    m_axis_data_tdata = Signal(intbv(0)[8:])
    m_axis_data_tvalid = Signal(bool(0))
    m_axis_data_tlast = Signal(bool(0))
    scl_o = Signal(bool(1))
    scl_t = Signal(bool(1))
    sda_o = Signal(bool(1))
    sda_t = Signal(bool(1))
    busy = Signal(bool(0))
    bus_address = Signal(intbv(0)[7:])
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

    # sources and sinks
    data_source_pause = Signal(bool(0))
    data_sink_pause = Signal(bool(0))

    data_source = axis_ep.AXIStreamSource()

    data_source_logic = data_source.create_logic(
        clk,
        rst,
        tdata=s_axis_data_tdata,
        tvalid=s_axis_data_tvalid,
        tready=s_axis_data_tready,
        tlast=s_axis_data_tlast,
        pause=data_source_pause,
        name='data_source'
    )

    data_sink = axis_ep.AXIStreamSink()

    data_sink_logic = data_sink.create_logic(
        clk,
        rst,
        tdata=m_axis_data_tdata,
        tvalid=m_axis_data_tvalid,
        tready=m_axis_data_tready,
        tlast=m_axis_data_tlast,
        pause=data_sink_pause,
        name='data_sink'
    )

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

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        release_bus=release_bus,
        s_axis_data_tdata=s_axis_data_tdata,
        s_axis_data_tvalid=s_axis_data_tvalid,
        s_axis_data_tready=s_axis_data_tready,
        s_axis_data_tlast=s_axis_data_tlast,
        m_axis_data_tdata=m_axis_data_tdata,
        m_axis_data_tvalid=m_axis_data_tvalid,
        m_axis_data_tready=m_axis_data_tready,
        m_axis_data_tlast=m_axis_data_tlast,
        scl_i=scl_i,
        scl_o=scl_o,
        scl_t=scl_t,
        sda_i=sda_i,
        sda_o=sda_o,
        sda_t=sda_t,
        busy=busy,
        bus_address=bus_address,
        bus_addressed=bus_addressed,
        bus_active=bus_active,
        enable=enable,
        device_address=device_address,
        device_address_mask=device_address_mask
    )

    @always_comb
    def bus():
        # emulate I2C wired AND
        m_scl_i.next = m_scl_o & scl_o & s2_scl_o;
        m_sda_i.next = m_sda_o & sda_o & s2_sda_o;

        scl_i.next = m_scl_o & scl_o & s2_scl_o;
        sda_i.next = m_sda_o & sda_o & s2_sda_o;

        s2_scl_i.next = m_scl_o & scl_o & s2_scl_o;
        s2_sda_i.next = m_sda_o & sda_o & s2_sda_o;

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
        device_address_mask.next = 0x7f

        yield clk.posedge
        print("test 1: write")
        current_test.next = 1

        i2c_master_inst.init_write(0x50, b'\x00\x04'+b'\x11\x22\x33\x44')

        yield i2c_master_inst.wait()
        yield clk.posedge

        data = None
        while not data:
            yield clk.posedge
            data = data_sink.recv()

        assert data.data == b'\x00\x04'+b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 2: read")
        current_test.next = 2

        i2c_master_inst.init_write(0x50, b'\x00\x04')
        i2c_master_inst.init_read(0x50, 4)

        data_source.send(b'\x11\x22\x33\x44')

        yield i2c_master_inst.wait()
        yield clk.posedge

        data = None
        while not data:
            yield clk.posedge
            data = data_sink.recv()

        assert data.data == b'\x00\x04'

        data = i2c_master_inst.get_read_data()
        assert data[0] == 0x50
        assert data[1] == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 3: read with delays")
        current_test.next = 3

        i2c_master_inst.init_write(0x50, b'\x00\x04')
        i2c_master_inst.init_read(0x50, 4)

        data_source.send(b'\x11\x22\x33\x44')

        data_source_pause.next = True
        data_sink_pause.next = True

        yield delay(5000)
        data_sink_pause.next = False

        yield delay(2000)
        data_source_pause.next = False

        yield i2c_master_inst.wait()
        yield clk.posedge

        data = None
        while not data:
            yield clk.posedge
            data = data_sink.recv()

        assert data.data == b'\x00\x04'

        data = i2c_master_inst.get_read_data()
        assert data[0] == 0x50
        assert data[1] == b'\x11\x22\x33\x44'

        yield delay(100)

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
