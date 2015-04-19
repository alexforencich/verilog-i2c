#!/usr/bin/env python
"""

Copyright (c) 2015 Alex Forencich

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

try:
    from queue import Queue
except ImportError:
    from Queue import Queue

import axis_ep

module = 'i2c_init'

srcs = []

srcs.append("../rtl/%s.v" % module)
srcs.append("test_%s.v" % module)

src = ' '.join(srcs)

build_cmd = "iverilog -o test_%s.vvp %s" % (module, src)

def dut_i2c_init(clk,
                 rst,
                 current_test,
                 cmd_address,
                 cmd_start,
                 cmd_read,
                 cmd_write,
                 cmd_write_multiple,
                 cmd_stop,
                 cmd_valid,
                 cmd_ready,
                 data_out,
                 data_out_valid,
                 data_out_ready,
                 data_out_last,
                 busy,
                 start):

    if os.system(build_cmd):
        raise Exception("Error running build command")
    return Cosimulation("vvp -m myhdl test_%s.vvp -lxt2" % module,
                clk=clk,
                rst=rst,
                current_test=current_test,
                cmd_address=cmd_address,
                cmd_start=cmd_start,
                cmd_read=cmd_read,
                cmd_write=cmd_write,
                cmd_write_multiple=cmd_write_multiple,
                cmd_stop=cmd_stop,
                cmd_valid=cmd_valid,
                cmd_ready=cmd_ready,
                data_out=data_out,
                data_out_valid=data_out_valid,
                data_out_ready=data_out_ready,
                data_out_last=data_out_last,
                busy=busy,
                start=start)

def bench():

    # Parameters


    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    cmd_ready = Signal(bool(0))
    data_out_ready = Signal(bool(0))
    start = Signal(bool(0))

    # Outputs
    cmd_address = Signal(intbv(0)[7:])
    cmd_start = Signal(bool(0))
    cmd_read = Signal(bool(0))
    cmd_write = Signal(bool(0))
    cmd_write_multiple = Signal(bool(0))
    cmd_stop = Signal(bool(0))
    cmd_valid = Signal(bool(0))
    data_out = Signal(intbv(0)[8:])
    data_out_valid = Signal(bool(0))
    data_out_last = Signal(bool(1))
    busy = Signal(bool(0))

    # sources and sinks
    cmd_sink_queue = Queue()
    cmd_sink_pause = Signal(bool(0))
    data_sink_queue = Queue()
    data_sink_pause = Signal(bool(0))

    cmd_sink = axis_ep.AXIStreamSink(clk,
                                     rst,
                                     tdata=(cmd_address, cmd_start, cmd_read, cmd_write, cmd_write_multiple, cmd_stop),
                                     tvalid=cmd_valid,
                                     tready=cmd_ready,
                                     fifo=cmd_sink_queue,
                                     pause=cmd_sink_pause,
                                     name='cmd_sink')

    data_sink = axis_ep.AXIStreamSink(clk,
                                     rst,
                                     tdata=data_out,
                                     tvalid=data_out_valid,
                                     tready=data_out_ready,
                                     tlast=data_out_last,
                                     fifo=data_sink_queue,
                                     pause=data_sink_pause,
                                     name='data_sink')

    # DUT
    dut = dut_i2c_init(clk,
                       rst,
                       current_test,
                       cmd_address,
                       cmd_start,
                       cmd_read,
                       cmd_write,
                       cmd_write_multiple,
                       cmd_stop,
                       cmd_valid,
                       cmd_ready,
                       data_out,
                       data_out_valid,
                       data_out_ready,
                       data_out_last,
                       busy,
                       start)

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
                f1 = cmd_sink_queue.get(False)
                f2 = data_sink_queue.get(False)
                assert f1.data[0][0] == a # address
                assert f1.data[0][1] == first # start
                assert f1.data[0][2] == 0 # read
                assert f1.data[0][3] == 1 # write
                assert f1.data[0][4] == 0 # write multiple
                assert f1.data[0][5] == 0 # stop
                assert f2.data[0] == d
                first = False
        
        # check for stop command
        f1 = cmd_sink_queue.get(False)
        assert f1.data[0][1] == 0 # start
        assert f1.data[0][2] == 0 # read
        assert f1.data[0][3] == 0 # write
        assert f1.data[0][4] == 0 # write multiple
        assert f1.data[0][5] == 1 # stop

        # make sure we got everything
        assert cmd_sink_queue.empty()
        assert data_sink_queue.empty()

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
                f1 = cmd_sink_queue.get(False)
                f2 = data_sink_queue.get(False)
                assert f1.data[0][0] == a # address
                assert f1.data[0][1] == first # start
                assert f1.data[0][2] == 0 # read
                assert f1.data[0][3] == 1 # write
                assert f1.data[0][4] == 0 # write multiple
                assert f1.data[0][5] == 0 # stop
                assert f2.data[0] == d
                first = False
        
        # check for stop command
        f1 = cmd_sink_queue.get(False)
        assert f1.data[0][1] == 0 # start
        assert f1.data[0][2] == 0 # read
        assert f1.data[0][3] == 0 # write
        assert f1.data[0][4] == 0 # write multiple
        assert f1.data[0][5] == 1 # stop

        # make sure we got everything
        assert cmd_sink_queue.empty()
        assert data_sink_queue.empty()

        yield delay(100)

        raise StopSimulation

    return dut, cmd_sink, data_sink, clkgen, check

def test_bench():
    sim = Simulation(bench())
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
