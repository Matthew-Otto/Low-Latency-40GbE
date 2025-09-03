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
async def test_alignment_gen(dut):
    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")


    cocotb.start_soon(Clock(dut.clk, 2, units="ps").start())
    await reset(dut)

    for _ in range(1<<17):
        dut.block_in.value = random.getrandbits(66)
        await RisingEdge(dut.clk)

        