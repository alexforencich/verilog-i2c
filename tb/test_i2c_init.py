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

module = 'i2c_init'
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

    m_axis_cmd_ready = Signal(bool(0))
    m_axis_data_tready = Signal(bool(0))
    start = Signal(bool(0))

    # Outputs
    m_axis_cmd_address = Signal(intbv(0)[7:])
    m_axis_cmd_start = Signal(bool(0))
    m_axis_cmd_read = Signal(bool(0))
    m_axis_cmd_write = Signal(bool(0))
    m_axis_cmd_write_multiple = Signal(bool(0))
    m_axis_cmd_stop = Signal(bool(0))
    m_axis_cmd_valid = Signal(bool(0))
    m_axis_data_tdata = Signal(intbv(0)[8:])
    m_axis_data_tvalid = Signal(bool(0))
    m_axis_data_tlast = Signal(bool(1))
    busy = Signal(bool(0))

    # sources and sinks
    cmd_sink_pause = Signal(bool(0))
    data_sink_pause = Signal(bool(0))

    cmd_sink = axis_ep.AXIStreamSink()

    cmd_sink_logic = cmd_sink.create_logic(
        clk,
        rst,
        tdata=(m_axis_cmd_address, m_axis_cmd_start, m_axis_cmd_read, m_axis_cmd_write, m_axis_cmd_write_multiple, m_axis_cmd_stop),
        tvalid=m_axis_cmd_valid,
        tready=m_axis_cmd_ready,
        pause=cmd_sink_pause,
        name='cmd_sink'
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

    # DUT
    if os.system(build_cmd):
        raise Exception("Error running build command")

    dut = Cosimulation(
        "vvp -m myhdl %s.vvp -lxt2" % testbench,
        clk=clk,
        rst=rst,
        current_test=current_test,
        m_axis_cmd_address=m_axis_cmd_address,
        m_axis_cmd_start=m_axis_cmd_start,
        m_axis_cmd_read=m_axis_cmd_read,
        m_axis_cmd_write=m_axis_cmd_write,
        m_axis_cmd_write_multiple=m_axis_cmd_write_multiple,
        m_axis_cmd_stop=m_axis_cmd_stop,
        m_axis_cmd_valid=m_axis_cmd_valid,
        m_axis_cmd_ready=m_axis_cmd_ready,
        m_axis_data_tdata=m_axis_data_tdata,
        m_axis_data_tvalid=m_axis_data_tvalid,
        m_axis_data_tready=m_axis_data_tready,
        m_axis_data_tlast=m_axis_data_tlast,
        busy=busy,
        start=start
    )

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
        print("test 1: run, no delays")
        current_test.next = 1

        start.next = 1
        yield clk.posedge
        start.next = 0
        yield clk.posedge
        yield clk.posedge

        while busy:
            yield clk.posedge

        # addresses and data for checking
        addr = [0x50, 0x50, 0x51, 0x52, 0x53]
        data = [0x00, 0x04, 0x11, 0x22, 0x33, 0x44]
        
        # check all issued commands
        for a in addr:
            first = True
            for d in data:
                f1 = cmd_sink.recv()
                f2 = data_sink.recv()
                assert f1.data[0][0] == a # address
                assert f1.data[0][1] == first # start
                assert f1.data[0][2] == 0 # read
                assert f1.data[0][3] == 1 # write
                assert f1.data[0][4] == 0 # write multiple
                assert f1.data[0][5] == 0 # stop
                assert f2.data[0] == d
                first = False
        
        # check for stop command
        f1 = cmd_sink.recv()
        assert f1.data[0][1] == 0 # start
        assert f1.data[0][2] == 0 # read
        assert f1.data[0][3] == 0 # write
        assert f1.data[0][4] == 0 # write multiple
        assert f1.data[0][5] == 1 # stop

        # make sure we got everything
        assert cmd_sink.empty()
        assert data_sink.empty()

        yield delay(100)

        # testbench stimulus

        yield clk.posedge
        print("test 2: run with delays")
        current_test.next = 2

        start.next = 1
        yield clk.posedge
        start.next = 0
        yield clk.posedge
        yield clk.posedge

        cmd_sink_pause.next = 0
        data_sink_pause.next = 1

        while busy:
            yield delay(100)
            yield clk.posedge
            cmd_sink_pause.next = 0
            data_sink_pause.next = 1
            yield clk.posedge
            cmd_sink_pause.next = 1
            data_sink_pause.next = 1
            yield delay(100)
            yield clk.posedge
            cmd_sink_pause.next = 1
            data_sink_pause.next = 0
            yield clk.posedge
            cmd_sink_pause.next = 1
            data_sink_pause.next = 1

        cmd_sink_pause.next = 0
        data_sink_pause.next = 0

        # addresses and data for checking
        addr = [0x50, 0x50, 0x51, 0x52, 0x53]
        data = [0x00, 0x04, 0x11, 0x22, 0x33, 0x44]
        
        # check all issued commands
        for a in addr:
            first = True
            for d in data:
                f1 = cmd_sink.recv()
                f2 = data_sink.recv()
                assert f1.data[0][0] == a # address
                assert f1.data[0][1] == first # start
                assert f1.data[0][2] == 0 # read
                assert f1.data[0][3] == 1 # write
                assert f1.data[0][4] == 0 # write multiple
                assert f1.data[0][5] == 0 # stop
                assert f2.data[0] == d
                first = False
        
        # check for stop command
        f1 = cmd_sink.recv()
        assert f1.data[0][1] == 0 # start
        assert f1.data[0][2] == 0 # read
        assert f1.data[0][3] == 0 # write
        assert f1.data[0][4] == 0 # write multiple
        assert f1.data[0][5] == 1 # stop

        # make sure we got everything
        assert cmd_sink.empty()
        assert data_sink.empty()

        yield delay(100)

        raise StopSimulation

    return instances()

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
