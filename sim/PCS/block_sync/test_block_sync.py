import cocotb
import random
import time
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from queue import Queue


@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    print("DUT reset")



@cocotb.test()
async def test_block_sync(dut):
    seed = 1756763862 #int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")


    cocotb.start_soon(Clock(dut.clk, 2, units="ps").start())
    await reset(dut)

    # initial lock
    for _ in range(random.randint(0,100)):
        if (random.random() < 9/10):
            dut.sync_bits.value = random.sample([0b11, 0b00], 1)[0]
        else:
            dut.sync_bits.value = random.sample([0b10, 0b01], 1)[0]
        await RisingEdge(dut.clk)

    # random noise
    for _ in range(10000):
        if (random.random() < 1/10):
            dut.sync_bits.value = random.sample([0b11, 0b00], 1)[0]
        else:
            dut.sync_bits.value = random.sample([0b10, 0b01], 1)[0]
        await RisingEdge(dut.clk)

        