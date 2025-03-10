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
import mmap

class I2CMaster(object):
    def __init__(self):
        self.command_queue = []
        self.read_data_queue = []
        self.has_logic = False
        self.clk = None
        self.busy = False

    def init_read(self, address, length):
        self.command_queue.append(('r', address, length))

    def init_write(self, address, data):
        self.command_queue.append(('w', address, data))

    def idle(self):
        return len(self.command_queue) == 0 and not self.busy

    def wait(self):
        while not self.idle():
            yield self.clk.posedge

    def read_data_ready(self):
        return len(self.read_data_queue) > 0

    def get_read_data(self):
        return self.read_data_queue.pop(0)

    def read(self, address, length):
        self.init_read(address, length)
        while not self.read_data_ready():
            yield clk.posedge
        return self.get_read_data()

    def write(self, address, data):
        self.init_write(address, data)
        yield self.wait()

    def create_logic(self,
                clk,
                rst,
                scl_i,
                scl_o,
                scl_t,
                sda_i,
                sda_o,
                sda_t,
                prescale=2,
                name=None
            ):

        if self.has_logic:
            raise Exception("Logic already instantiated!")

        self.has_logic = True
        self.clk = clk

        line_state = [False]

        def send_start():
            if line_state[0]:
                sda_o.next = 1
                sda_t.next = 1

                for i in range(prescale):
                    yield clk.posedge

                scl_o.next = 1
                scl_t.next = 1

                while not scl_i:
                    yield clk.posedge

                for i in range(prescale):
                    yield clk.posedge

            sda_o.next = 0
            sda_t.next = 0

            for i in range(prescale):
                yield clk.posedge

            scl_o.next = 0
            scl_t.next = 0

            for i in range(prescale):
                yield clk.posedge

            line_state[0] = True

        def send_stop():
            if not line_state[0]:
                return

            sda_o.next = 0
            sda_t.next = 0

            for i in range(prescale):
                yield clk.posedge

            scl_o.next = 1
            scl_t.next = 1

            while not scl_i:
                yield clk.posedge

            for i in range(prescale):
                yield clk.posedge

            sda_o.next = 1
            sda_t.next = 1

            for i in range(prescale):
                yield clk.posedge

            line_state[0] = False

        def send_bit(b):
            if not line_state[0]:
                send_start()

            sda_o.next = bool(b)
            sda_t.next = bool(b)

            for i in range(prescale):
                yield clk.posedge

            scl_o.next = 1
            scl_t.next = 1

            while not scl_i:
                yield clk.posedge

            for i in range(prescale*2):
                yield clk.posedge

            scl_o.next = 0
            scl_t.next = 0

            for i in range(prescale):
                yield clk.posedge


        def receive_bit(b):
            if len(b) == 0:
                b.append(0)

            if not line_state[0]:
                send_start()

            sda_o.next = 1
            sda_t.next = 1

            for i in range(prescale):
                yield clk.posedge

            scl_o.next = 1
            scl_t.next = 1

            while not scl_i:
                yield clk.posedge

            b[0] = int(sda_i)

            for i in range(prescale*2):
                yield clk.posedge

            scl_o.next = 0
            scl_t.next = 0

            for i in range(prescale):
                yield clk.posedge

        def send_byte(b, ack):
            for i in range(8):
                yield send_bit(b & (1 << 7-i))
            yield receive_bit(ack)

        def receive_byte(b, ack):
            if len(b) == 0:
                b.append(0)
            b[0] = 0
            for i in range(8):
                v = []
                yield receive_bit(v)
                b[0] = (b[0] << 1) | v[0]
            yield send_bit(ack)

        @instance
        def logic():
            while True:
                yield clk.posedge
                self.busy = False

                # check for commands
                if len(self.command_queue) > 0:
                    cmd = self.command_queue.pop(0)
                    self.busy = True

                    addr = cmd[1]

                    if cmd[0] == 'w':
                        # write command

                        data = cmd[2]

                        if name is not None:
                            print("[%s] Write data a:0x%02x d:%s" % (name, addr, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                        yield send_start()

                        ack = []
                        yield send_byte(addr << 1 | 0, ack)

                        if ack[0]:
                            print("[%s] No ACK from slave" % name)

                        for k in range(len(data)):
                            ack = []
                            yield send_byte(data[k], ack)

                            if ack[0]:
                                print("[%s] No ACK from slave" % name)

                    elif cmd[0] == 'r':
                        # read command
                        yield send_start()

                        ack = []
                        yield send_byte(addr << 1 | 1, ack)

                        if ack[0]:
                            print("[%s] No ACK from slave" % name)

                        cnt = cmd[2]
                        data = b''

                        for k in range(cnt):
                            d = []
                            yield receive_byte(d, k == cnt-1)
                            data = data + bytearray([d[0]])

                        if name is not None:
                            print("[%s] Read data a:0x%02x d:%s" % (name, addr, " ".join(("{:02x}".format(c) for c in bytearray(data)))))

                        self.read_data_queue.append((addr, data))

                    else:
                        # bad command; ignore it
                        continue

                elif line_state[0]:
                    # send stop
                    yield send_stop()

        return instances()


class I2CMem(object):
    def __init__(self, size = 1024):
        self.size = size
        self.mem = mmap.mmap(-1, size)
        self.has_logic = False

    def read_mem(self, address, length):
        self.mem.seek(address)
        return self.mem.read(length)

    def write_mem(self, address, data):
        self.mem.seek(address)
        self.mem.write(data)

    def create_logic(self,
                scl_i,
                scl_o,
                scl_t,
                sda_i,
                sda_o,
                sda_t,
                abw=2,
                address=0x50,
                latency=0,
                name=None
            ):
        
        if self.has_logic:
            raise Exception("Logic already instantiated!")

        self.has_logic = True

        def send_bit(b):
            if scl_i:
                yield scl_i.negedge

            sda_o.next = bool(b)
            sda_t.next = bool(b)

            if not scl_o:
                yield delay(10)

                scl_o.next = 1
                scl_t.next = 1

            yield scl_i.negedge

            sda_o.next = 1
            sda_t.next = 1

        def receive_bit(b):
            scl_o.next = 1
            scl_t.next = 1

            if len(b) == 0:
                b.append(0)

            sda_o.next = 1
            sda_t.next = 1

            if scl_i:
                yield scl_i.negedge, sda_i.posedge, sda_i.negedge

                if scl_i:
                    # Got start or stop bit
                    if sda_i:
                        b[0] = 'stop'
                    else:
                        b[0] = 'start'
                    return

            last_scl = int(scl_i)
            last_sda = int(sda_i)

            yield scl_i.posedge

            b[0] = int(sda_i)

        def send_byte(b, ack):
            for i in range(8):
                yield from send_bit(b & (1 << 7-i))
            yield receive_bit(ack)

        def receive_byte(b, ack):
            if len(b) == 0:
                b.append(0)
            b[0] = 0
            for i in range(8):
                v = []
                yield receive_bit(v)
                if type(v[0]) is str:
                    b[0] = v[0]
                    return
                b[0] = (b[0] << 1) | v[0]
            yield send_bit(ack)

        @instance
        def logic():
            count = 0
            ptr = 0
            line_active = False

            while True:
                sda_o.next = 1
                sda_t.next = 1

                yield sda_i.negedge

                if scl_i:
                    # start condition
                    if name is not None:
                        print("[%s] Got start bit" % name)

                    line_active = True
                    while line_active:
                        # read address
                        addr = 0
                        for i in range(8):
                            v = []
                            yield receive_bit(v)
                            if type(v[0]) is str:
                                addr = v[0]
                                break
                            else:
                                addr = (addr << 1) | v[0]

                        if addr == 'stop':
                            # Stop bit
                            if name is not None:
                                print("[%s] Got stop bit" % name)
                            line_active = False
                            break
                        elif addr == 'start':
                            # Stop bit
                            if name is not None:
                                print("[%s] Got repeated start bit" % name)
                            break

                        rw = addr & 1
                        addr = addr >> 1

                        if addr == address:
                            # address for me
                            yield send_bit(0)

                            if rw:
                                # read
                                if name is not None:
                                    print("[%s] Address matched (read)" % name)

                                while True:
                                    if latency > 0:
                                        if scl_i:
                                            yield scl_i.negedge

                                        scl_o.next = 0
                                        scl_t.next = 0

                                        yield delay(latency)

                                    self.mem.seek(ptr)
                                    v = self.mem.read(1)[0]
                                    ack = []

                                    yield send_byte(v, ack)

                                    if name is not None:
                                        print("[%s] Read data a:0x%0*x d:%02x" % (name, abw*2, ptr, v))

                                    ptr = ptr + 1

                                    if ack[0]:
                                        if name is not None:
                                            print("[%s] Got NACK" % name)
                                        break
                            else:
                                # write
                                if name is not None:
                                    print("[%s] Address matched (write)" % name)

                                ptr = 0
                                for k in range(abw):
                                    v = []
                                    yield receive_byte(v, 0)
                                    ptr = (ptr << 8) | v[0]

                                if name is not None:
                                    print("[%s] Set address pointer 0x%0*x" % (name, abw*2, ptr))
                                
                                while True:
                                    if latency > 0:
                                        if scl_i:
                                            yield scl_i.negedge

                                        scl_o.next = 0
                                        scl_t.next = 0

                                        yield delay(latency)

                                    v = []
                                    yield receive_byte(v, 0)
                                    if v[0] == 'stop':
                                        # Stop bit
                                        if name is not None:
                                            print("[%s] Got stop bit" % name)
                                        line_active = False
                                        break
                                    elif v[0] == 'start':
                                        # Repeated start
                                        if name is not None:
                                            print("[%s] Got repeated start bit" % name)
                                        break
                                    self.mem.seek(ptr)
                                    self.mem.write(bytes(bytearray([v[0]])))

                                    if name is not None:
                                        print("[%s] Write data a:0x%0*x d:%02x" % (name, abw*2, ptr, v[0]))

                                    ptr = ptr + 1
                        else:
                            # no match, wait for start
                            break

        return instances()
