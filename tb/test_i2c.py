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

import i2c

def bench():

    # Inputs
    clk = Signal(bool(0))
    rst = Signal(bool(0))
    current_test = Signal(intbv(0)[8:])

    m_scl_i = Signal(bool(1))
    m_sda_i = Signal(bool(1))

    s1_scl_i = Signal(bool(1))
    s1_sda_i = Signal(bool(1))

    s2_scl_i = Signal(bool(1))
    s2_sda_i = Signal(bool(1))

    # Outputs
    m_scl_o = Signal(bool(1))
    m_scl_t = Signal(bool(1))
    m_sda_o = Signal(bool(1))
    m_sda_t = Signal(bool(1))

    s1_scl_o = Signal(bool(1))
    s1_scl_t = Signal(bool(1))
    s1_sda_o = Signal(bool(1))
    s1_sda_t = Signal(bool(1))

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
        prescale=2,
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

    @always_comb
    def bus():
        # emulate I2C wired AND
        m_scl_i.next = m_scl_o & s1_scl_o & s2_scl_o;
        m_sda_i.next = m_sda_o & s1_sda_o & s2_sda_o;

        s1_scl_i.next = m_scl_o & s1_scl_o & s2_scl_o;
        s1_sda_i.next = m_sda_o & s1_sda_o & s2_sda_o;

        s2_scl_i.next = m_scl_o & s1_scl_o & s2_scl_o;
        s2_sda_i.next = m_sda_o & s1_sda_o & s2_sda_o;

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

        yield clk.posedge
        print("test 1: baseline")
        current_test.next = 1

        data = i2c_mem_inst1.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        yield delay(100)

        yield clk.posedge
        print("test 2: direct write")
        current_test.next = 2

        i2c_mem_inst1.write_mem(0, b'test')

        data = i2c_mem_inst1.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert i2c_mem_inst1.read_mem(0,4) == b'test'

        yield delay(100)

        yield clk.posedge
        print("test 3: write via I2C")
        current_test.next = 3

        i2c_master_inst.init_write(0x50, b'\x00\x04'+b'\x11\x22\x33\x44')

        yield i2c_master_inst.wait()
        yield clk.posedge

        data = i2c_mem_inst1.read_mem(0, 32)
        for i in range(0, len(data), 16):
            print(" ".join(("{:02x}".format(c) for c in bytearray(data[i:i+16]))))

        assert i2c_mem_inst1.read_mem(4,4) == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 4: read via I2C")
        current_test.next = 4

        i2c_master_inst.init_write(0x50, b'\x00\x04')
        i2c_master_inst.init_read(0x50, 4)

        yield i2c_master_inst.wait()
        yield clk.posedge

        data = i2c_master_inst.get_read_data()
        assert data[0] == 0x50
        assert data[1] == b'\x11\x22\x33\x44'

        yield delay(100)

        yield clk.posedge
        print("test 5: access slave 2")
        current_test.next = 3

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

    return i2c_master_logic, i2c_mem_logic1, i2c_mem_logic2, bus, clkgen, check

def test_bench():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    #sim = Simulation(bench())
    traceSignals.name = os.path.basename(__file__).rsplit('.',1)[0]
    sim = Simulation(traceSignals(bench))
    sim.run()

if __name__ == '__main__':
    print("Running test...")
    test_bench()
