"""

Copyright (c) 2015-2016 Alex Forencich

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
import mmap

class WBMaster(object):
    def __init__(self):
        self.command_queue = []
        self.read_data_queue = []
        self.has_logic = False
        self.clk = None
        self.cyc_o = None

    def init_read(self, address, length):
        self.command_queue.append(('r', address, length))

    def init_read_words(self, address, length, ws=2):
        assert ws in (1, 2, 4, 8)
        self.init_read(int(address*ws), int(length*ws))

    def init_read_dwords(self, address, length):
        self.init_read_words(address, length, 4)

    def init_read_qwords(self, address, length):
        self.init_read_words(address, length, 8)

    def init_write(self, address, data):
        self.command_queue.append(('w', address, data))

    def init_write_words(self, address, data, ws=2):
        assert ws in (1, 2, 4, 8)
        data2 = []
        for w in data:
            d = []
            for j in range(ws):
                d.append(w&0xff)
                w >>= 8
            data2.extend(bytearray(d))
        self.init_write(int(address*ws), data2)

    def init_write_dwords(self, address, data):
        self.init_write_words(address, data, 4)

    def init_write_qwords(self, address, data):
        self.init_write_words(address, data, 8)

    def idle(self):
        return len(self.command_queue) == 0 and not self.cyc_o.next

    def wait(self):
        while not self.idle():
            yield self.clk.posedge

    def read_data_ready(self):
        return not self.read_data_queue

    def get_read_data(self):
        return self.read_data_queue.pop(0)

    def get_read_data_words(self, ws=2):
        assert ws in (1, 2, 4, 8)
        v = self.get_read_data()
        if v is None:
            return None
        address, data = v
        d = []
        for i in range(int(len(data)/ws)):
            w = 0
            for j in range(ws-1,-1,-1):
                w <<= 8
                w += data[i*ws+j]
            d.append(w)
        return (int(address/ws), d)

    def get_read_data_dwords(self):
        return self.get_read_data_words(4)

    def get_read_data_qwords(self):
        return self.get_read_data_words(8)

    def create_logic(self,
                clk,
                adr_o=Signal(intbv(0)[8:]),
                dat_i=None,
                dat_o=None,
                we_o=Signal(bool(0)),
                sel_o=Signal(intbv(1)[1:]),
                stb_o=Signal(bool(0)),
                ack_i=Signal(bool(0)),
                cyc_o=Signal(bool(0)),
                name=None
            ):

        if self.has_logic:
            raise Exception("Logic already instantiated!")

        if dat_i is not None:
            assert len(dat_i) % 8 == 0
            w = len(dat_i)
        if dat_o is not None:
            assert len(dat_o) % 8 == 0
            w = len(dat_o)
        if dat_i is not None and dat_o is not None:
            assert len(dat_i) == len(dat_o)

        bw = int(w/8)   # width of bus in bytes
        ww = len(sel_o) # width of bus in words
        ws = int(bw/ww) # word size in bytes

        assert ww in (1, 2, 4, 8)
        assert ws in (1, 2, 4, 8)

        self.has_logic = True
        self.clk = clk
        self.cyc_o = cyc_o

        @instance
        def logic():
            while True:
                yield clk.posedge

                # check for commands
                if len(self.command_queue) > 0:
                    cmd = self.command_queue.pop(0)

                    # address
                    addr = cmd[1]
                    # address in words
                    adw = int(addr/ws)
                    # select for first access
                    sel_start = ((2**(ww)-1) << int(adw % ww)) & (2**(ww)-1)

                    if cmd[0] == 'w':
                        data = cmd[2]
                        # select for last access
                        sel_end = (2**(ww)-1) >> int(ww - (((int((addr+len(data)-1)/ws)) % ww) + 1))
                        # number of cycles
                        cycles = int((len(data) + bw-1 + (addr % bw)) / bw)
                        i = 0

                        if name is not None:
                            print("[%s] Write data a:0x%08x d:%s" % (name, addr, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                        cyc_o.next = 1

                        # first cycle
                        stb_o.next = 1
                        we_o.next = 1
                        adr_o.next = int(adw/ww)*ww
                        val = 0
                        for j in range(bw):
                            if j >= addr % bw and (cycles > 1 or j < (((addr + len(data) - 1) % bw) + 1)):
                                val |= bytearray(data)[i] << j*8
                                i += 1
                        dat_o.next = val

                        if cycles == 1:
                            sel_o.next = sel_start & sel_end
                        else:
                            sel_o.next = sel_start

                        yield clk.posedge
                        while not int(ack_i):
                            yield clk.posedge

                        stb_o.next = 0
                        we_o.next = 0

                        for k in range(1, cycles-1):
                            # middle cycles
                            yield clk.posedge
                            stb_o.next = 1
                            we_o.next = 1
                            adr_o.next = int(adw/ww)*ww + k * ww
                            val = 0
                            for j in range(bw):
                                val |= bytearray(data)[i] << j*8
                                i += 1
                            dat_o.next = val
                            sel_o.next = 2**(ww)-1

                            yield clk.posedge
                            while not int(ack_i):
                                yield clk.posedge

                            stb_o.next = 0
                            we_o.next = 0

                        if cycles > 1:
                            # last cycle
                            yield clk.posedge
                            stb_o.next = 1
                            we_o.next = 1
                            adr_o.next = int(adw/ww)*ww + (cycles-1) * ww
                            val = 0
                            for j in range(bw):
                                if j < (((addr + len(data) - 1) % bw) + 1):
                                    val |= bytearray(data)[i] << j*8
                                    i += 1
                            dat_o.next = val
                            sel_o.next = sel_end

                            yield clk.posedge
                            while not int(ack_i):
                                yield clk.posedge

                            stb_o.next = 0
                            we_o.next = 0

                        we_o.next = 0
                        stb_o.next = 0

                        cyc_o.next = 0

                    elif cmd[0] == 'r':
                        length = cmd[2]
                        data = b''
                        # select for last access
                        sel_end = (2**(ww)-1) >> int(ww - (((int((addr+length-1)/ws)) % ww) + 1))
                        # number of cycles
                        cycles = int((length + bw-1 + (addr % bw)) / bw)

                        cyc_o.next = 1

                        # first cycle
                        stb_o.next = 1
                        adr_o.next = int(adw/ww)*ww
                        if cycles == 1:
                            sel_o.next = sel_start & sel_end
                        else:
                            sel_o.next = sel_start

                        yield clk.posedge
                        while not int(ack_i):
                            yield clk.posedge

                        stb_o.next = 0

                        val = int(dat_i)

                        for j in range(bw):
                            if j >= addr % bw and (cycles > 1 or j < (((addr + length - 1) % bw) + 1)):
                                data += bytes(bytearray([(val >> j*8) & 255]))

                        for k in range(1, cycles-1):
                            # middle cycles
                            yield clk.posedge
                            stb_o.next = 1
                            adr_o.next = int(adw/ww)*ww + k * ww
                            sel_o.next = 2**(ww)-1

                            yield clk.posedge
                            while not int(ack_i):
                                yield clk.posedge

                            stb_o.next = 0

                            val = int(dat_i)

                            for j in range(bw):
                                data += bytes(bytearray([(val >> j*8) & 255]))

                        if cycles > 1:
                            # last cycle
                            yield clk.posedge
                            stb_o.next = 1
                            adr_o.next = int(adw/ww)*ww + (cycles-1) * ww
                            sel_o.next = sel_end

                            yield clk.posedge
                            while not int(ack_i):
                                yield clk.posedge

                            stb_o.next = 0

                            val = int(dat_i)

                            for j in range(bw):
                                if j < (((addr + length - 1) % bw) + 1):
                                    data += bytes(bytearray([(val >> j*8) & 255]))

                        stb_o.next = 0
                        cyc_o.next = 0

                        if name is not None:
                            print("[%s] Read data a:0x%08x d:%s" % (name, addr, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                        self.read_data_queue.append((addr, data))

        return instances()


class WBRam(object):
    def __init__(self, size = 1024):
        self.size = size
        self.mem = mmap.mmap(-1, size)

    def read_mem(self, address, length):
        self.mem.seek(address)
        return self.mem.read(length)

    def write_mem(self, address, data):
        self.mem.seek(address)
        self.mem.write(data)

    def read_words(self, address, length, ws=2):
        assert ws in (1, 2, 4, 8)
        self.mem.seek(int(address*ws))
        d = []
        for i in range(length):
            w = 0
            data = bytearray(self.mem.read(ws))
            for j in range(ws-1,-1,-1):
                w <<= 8
                w += data[j]
            d.append(w)
        return d

    def read_dwords(self, address, length):
        return self.read_words(address, length, 4)

    def read_qwords(self, address, length):
        return self.read_words(address, length, 8)

    def write_words(self, address, data, ws=2):
        assert ws in (1, 2, 4, 8)
        self.mem.seek(int(address*ws))
        for w in data:
            d = []
            for j in range(ws):
                d.append(w&0xff)
                w >>= 8
            self.mem.write(bytearray(d))

    def write_dwords(self, address, length):
        return self.write_words(address, length, 4)

    def write_qwords(self, address, length):
        return self.write_words(address, length, 8)

    def create_port(self,
                clk,
                adr_i=Signal(intbv(0)[8:]),
                dat_i=None,
                dat_o=None,
                we_i=Signal(bool(0)),
                sel_i=Signal(intbv(1)[1:]),
                stb_i=Signal(bool(0)),
                ack_o=Signal(bool(0)),
                cyc_i=Signal(bool(0)),
                latency=1,
                asynchronous=False,
                name=None
            ):

        if dat_i is not None:
            assert len(dat_i) % 8 == 0
            w = len(dat_i)
        if dat_o is not None:
            assert len(dat_o) % 8 == 0
            w = len(dat_o)
        if dat_i is not None and dat_o is not None:
            assert len(dat_i) == len(dat_o)

        bw = int(w/8)   # width of bus in bytes
        ww = len(sel_i) # width of bus in words
        ws = int(bw/ww) # word size in bytes

        assert ww in (1, 2, 4, 8)
        assert ws in (1, 2, 4, 8)

        @instance
        def logic():
            while True:
                if asynchronous:
                    yield adr_i, cyc_i, stb_i
                else:
                    yield clk.posedge

                ack_o.next = False

                # address in increments of bus word width
                addr = int(int(adr_i)/ww)*ww

                if cyc_i & stb_i & ~ack_o:
                    if asynchronous:
                        yield delay(latency)
                    else:
                        for i in range(latency):
                            yield clk.posedge
                    ack_o.next = True
                    self.mem.seek(addr*ws % self.size)
                    if we_i:
                        # write
                        data = []
                        val = int(dat_i)
                        for i in range(bw):
                            data += [val & 0xff]
                            val >>= 8
                        data = bytearray(data)
                        for i in range(ww):
                            if sel_i & (1 << i):
                                self.mem.write(data[i*ws:(i+1)*ws])
                            else:
                                self.mem.seek(ws, 1)
                        if name is not None:
                            print("[%s] Write word a:0x%08x sel:0x%02x d:%s" % (name, addr, sel_i, " ".join(("{:02x}".format(c) for c in bytearray(data)))))
                    else:
                        data = bytearray(self.mem.read(bw))
                        val = 0
                        for i in range(bw-1,-1,-1):
                            val <<= 8
                            val += data[i]
                        dat_o.next = val
                        if name is not None:
                            print("[%s] Read word a:0x%08x d:%s" % (name, addr, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

        return instances()
