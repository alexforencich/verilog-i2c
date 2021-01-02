#!/usr/bin/env python
"""

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

"""

from myhdl import *
import os

import axis_ep
import i2c

module = 'i2c_master'
testbench = 'test_%s' % module

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

def bench():

    # Parameters


    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    s_axis_cmd_address = Signal(intbv(0)[7:])
    s_axis_cmd_start = Signal(bool(0))
    s_axis_cmd_read = Signal(bool(0))
    s_axis_cmd_write = Signal(bool(0))
    s_axis_cmd_write_multiple = Signal(bool(0))
    s_axis_cmd_stop = Signal(bool(0))
    s_axis_cmd_valid = Signal(bool(0))
    s_axis_data_tdata = Signal(intbv(0)[8:])
    s_axis_data_tvalid = Signal(bool(0))
    s_axis_data_tlast = Signal(bool(0))
    m_axis_data_tready = Signal(bool(0))
    scl_i = Signal(bool(1))
    sda_i = Signal(bool(1))
    prescale = Signal(intbv(0)[16:])
    stop_on_idle = Signal(bool(0))

    s1_scl_i = Signal(bool(1))
    s1_sda_i = Signal(bool(1))

    s2_scl_i = Signal(bool(1))
    s2_sda_i = Signal(bool(1))

    # Outputs
    s_axis_cmd_ready = Signal(bool(0))
    s_axis_data_tready = Signal(bool(0))
    m_axis_data_tdata = Signal(intbv(0)[8:])
    m_axis_data_tvalid = Signal(bool(0))
    m_axis_data_tlast = Signal(bool(0))
    scl_o = Signal(bool(1))
    scl_t = Signal(bool(1))
    sda_o = Signal(bool(1))
    sda_t = Signal(bool(1))
    busy = Signal(bool(0))
    bus_control = Signal(bool(0))
    bus_active = Signal(bool(0))
    missed_ack = Signal(bool(0))

    s1_scl_o = Signal(bool(1))
    s1_scl_t = Signal(bool(1))
    s1_sda_o = Signal(bool(1))
    s1_sda_t = Signal(bool(1))

    s2_scl_o = Signal(bool(1))
    s2_scl_t = Signal(bool(1))
    s2_sda_o = Signal(bool(1))
    s2_sda_t = Signal(bool(1))

    # sources and sinks
    cmd_source_pause = Signal(bool(0))
    data_source_pause = Signal(bool(0))
    data_sink_pause = Signal(bool(0))

    cmd_source = axis_ep.AXIStreamSource()

    cmd_source_logic = cmd_source.create_logic(
        clk,
        rst,
        tdata=(s_axis_cmd_address, s_axis_cmd_start, s_axis_cmd_read, s_axis_cmd_write, s_axis_cmd_write_multiple, s_axis_cmd_stop),
        tvalid=s_axis_cmd_valid,
        tready=s_axis_cmd_ready,
        pause=cmd_source_pause,
        name='cmd_source'
    )

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

        s_axis_cmd_address=s_axis_cmd_address,
        s_axis_cmd_start=s_axis_cmd_start,
        s_axis_cmd_read=s_axis_cmd_read,
        s_axis_cmd_write=s_axis_cmd_write,
        s_axis_cmd_write_multiple=s_axis_cmd_write_multiple,
        s_axis_cmd_stop=s_axis_cmd_stop,
        s_axis_cmd_valid=s_axis_cmd_valid,
        s_axis_cmd_ready=s_axis_cmd_ready,

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
        bus_control=bus_control,
        bus_active=bus_active,
        missed_ack=missed_ack,

        prescale=prescale,
        stop_on_idle=stop_on_idle
    )

    @always_comb
    def bus():
        # emulate I2C wired AND
        scl_i.next = scl_o & s1_scl_o & s2_scl_o;
        sda_i.next = sda_o & s1_sda_o & s2_sda_o;

        s1_scl_i.next = scl_o & s1_scl_o & s2_scl_o;
        s1_sda_i.next = sda_o & s1_sda_o & s2_sda_o;

        s2_scl_i.next = scl_o & s1_scl_o & s2_scl_o;
        s2_sda_i.next = sda_o & s1_sda_o & s2_sda_o;

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

        prescale.next = 2

        yield clk.posedge

        # testbench stimulus

        yield clk.posedge
        print("test 1: write")
        current_test.next = 1

        cmd_source.send([(
            0x50, # address
            0,    # start
            0,    # read
            0,    # write
            1,    # write_multiple
            1     # stop
        )])
        data_source.send((b'\x00\x04'+b'\x11\x22\x33\x44'))

        yield clk.posedge
        yield clk.posedge
        yield clk.posedge
        while busy or bus_active or not cmd_source.empty():
            yield clk.posedge
        yield clk.posedge

        data = i2c_mem_inst1.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert i2c_mem_inst1.read_mem(4,4) == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 2: read")
        current_test.next = 2

        cmd_source.send([(
            0x50, # address
            0,    # start
            0,    # read
            0,    # write
            1,    # write_multiple
            0     # stop
        )])
        data_source.send((b'\x00\x04'))

        for i in range(3):
            cmd_source.send([(
                0x50, # address
                0,    # start
                1,    # read
                0,    # write
                0,    # write_multiple
                0     # stop
            )])

        cmd_source.send([(
            0x50, # address
            0,    # start
            1,    # read
            0,    # write
            0,    # write_multiple
            1     # stop
        )])

        yield clk.posedge
        yield clk.posedge
        yield clk.posedge
        while busy or bus_active or not cmd_source.empty():
            yield clk.posedge
        yield clk.posedge

        data = data_sink.recv()
        assert data.data == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 3: write to slave 2")
        current_test.next = 3

        cmd_source.send([(
            0x51, # address
            0,    # start
            0,    # read
            0,    # write
            1,    # write_multiple
            1     # stop
        )])
        data_source.send((b'\x00\x04'+b'\x44\x33\x22\x11'))

        yield clk.posedge
        yield clk.posedge
        yield clk.posedge
        while busy or bus_active or not cmd_source.empty():
            yield clk.posedge
        yield clk.posedge

        data = i2c_mem_inst1.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert i2c_mem_inst2.read_mem(4,4) == b'\x44\x33\x22\x11'

        yield delay(100)

        yield clk.posedge
        print("test 4: read from slave 2")
        current_test.next = 4

        cmd_source.send([(
            0x51, # address
            0,    # start
            0,    # read
            0,    # write
            1,    # write_multiple
            0     # stop
        )])
        data_source.send((b'\x00\x04'))

        for i in range(3):
            cmd_source.send([(
                0x51, # address
                0,    # start
                1,    # read
                0,    # write
                0,    # write_multiple
                0     # stop
            )])

        cmd_source.send([(
            0x51, # address
            0,    # start
            1,    # read
            0,    # write
            0,    # write_multiple
            1     # stop
        )])

        yield clk.posedge
        yield clk.posedge
        yield clk.posedge
        while busy or bus_active or not cmd_source.empty():
            yield clk.posedge
        yield clk.posedge

        data = data_sink.recv()
        assert data.data == b'\x44\x33\x22\x11'

        yield delay(100)

        yield clk.posedge
        print("test 5: write to nonexistent device")
        current_test.next = 5

        cmd_source.send([(
            0x52, # address
            0,    # start
            0,    # read
            0,    # write
            1,    # write_multiple
            1     # stop
        )])
        data_source.send((b'\x00\x04'+b'\xde\xad\xbe\xef'))

        got_missed_ack = False

        for k in range(1000):
            got_missed_ack |= missed_ack
            yield clk.posedge

        assert got_missed_ack

        yield clk.posedge
        yield clk.posedge
        yield clk.posedge
        while busy or bus_active or not cmd_source.empty():
            yield clk.posedge
        yield clk.posedge

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
