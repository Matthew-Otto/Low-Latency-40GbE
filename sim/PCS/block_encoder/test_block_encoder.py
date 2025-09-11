import cocotb
import random
import time
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock


@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    print("DUT reset")


@cocotb.test()
async def test_encoder(dut):
    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 2, units="ps").start())
    await reset(dut)

    dut.en.value = 1

    # idles
    await ClockCycles(dut.clk, 10)

    dut.data_in.value = random.getrandbits(64)
    dut.valid_bytes.value = 0xfe
    await RisingEdge(dut.clk)
    
    for _ in range(9):
        dut.data_in.value = random.getrandbits(64)
        dut.valid_bytes.value = 0xff
        await RisingEdge(dut.clk)

    dut.data_in.value = random.getrandbits(40)
    dut.valid_bytes.value = 0x1f
    await RisingEdge(dut.clk)

    dut.valid_bytes.value = 0x0
    await ClockCycles(dut.clk, 10)
    



    