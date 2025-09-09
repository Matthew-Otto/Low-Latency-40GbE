import cocotb
import random
import time
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from queue import Queue


@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.clk_in)
    dut.clk_in_reset.value = 1
    dut.clk_out_reset.value = 1
    await ClockCycles(dut.clk_in, 5)
    dut.clk_in_reset.value = 0
    dut.clk_out_reset.value = 0
    print("DUT reset")


async def write_data(dut, ref_fifo, iters):
    for _ in range(iters):
        block = random.getrandbits(66)
        ref_fifo.put(block)
        dut._log.debug(f"{_} writing data >>{hex(block)}")
        dut.data_in.value = block
        dut.valid_in.value = 1
        await RisingEdge(dut.clk_in)
    dut.valid_in.value = 0


async def read_data(dut, ref_fifo, iters):
    buffer = 0
    buffer_size = 0

    for _ in range(iters):
        # wait for fifo to have valid data
        await FallingEdge(dut.clk_out)
        while not dut.valid_out.value:
            await FallingEdge(dut.clk_out)

        # build reference block
        while buffer_size < 32:
            assert ref_fifo.qsize() != 0, "ref fifo is empty?"
            w = ref_fifo.get()
            dut._log.debug(f"read from ref fifo: {hex(w)}")
            buffer |= w << buffer_size
            buffer_size += 66
        ref_block = buffer & ((1<<32)- 1)
        buffer >>= 32
        buffer_size -=32
        dut._log.debug(f"ref block: {hex(ref_block)}")

        # read data
        block = dut.data_out.value
        dut._log.debug(f"{_} reading data <<{hex(block)}")

        assert block == ref_block, f"FIFO output invalid | read {hex(block)} : reference {hex(ref_block)}"

        await RisingEdge(dut.clk_out)


async def write_sequence(dut, iters):
    sequence = ""
    for _ in range(4):
        #sequence += "01"
        sequence += "".join(random.choice('01') for _ in range(64))

    front_idx = len(sequence) - 32
    sequence = int(sequence, 2)

    for _ in range(iters):
        print(f"seq: {hex(sequence)}")
        block = sequence & ((1<<32)-1)
        sequence >>= 32
        sequence |= block << front_idx

        dut.data_in.value = block
        dut.valid_in.value = 1
        await RisingEdge(dut.clk_in)
    dut.valid_in.value = 0


async def read_sequence(dut, iters):
    for _ in range(iters):
        if random.random() < 0.1:
            dut.bitslip.value = 1
            print(f"bitslip")
        else:
            dut.bitslip.value = 0
            
        block = dut.data_out.value
        print(f"read block: {hex(block)}")
        await RisingEdge(dut.clk_out)


@cocotb.test()
async def test_tx_gearbox(dut):
    dut._log.setLevel("DEBUG")

    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    iters = 10000
    ref_fifo = Queue()

    cocotb.start_soon(Clock(dut.clk_in, 66, units="ps").start())
    cocotb.start_soon(Clock(dut.clk_out, 32, units="ps").start())
    await reset(dut)

    buffer = 0
    size = 0

    fifo_write = cocotb.start_soon(write_data(dut, ref_fifo, 32*iters))
    fifo_read = cocotb.start_soon(read_data(dut, ref_fifo, 66*iters))

    await fifo_write
    await fifo_read


    