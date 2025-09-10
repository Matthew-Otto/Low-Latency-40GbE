import cocotb
import random
import time
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock
from queue import Queue


@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.core_clk)
    dut.core_reset.value = 1
    await ClockCycles(dut.core_clk, 5)
    dut.core_reset.value = 0
    print("DUT reset")


async def loopback(dut):
    while True:
        await RisingEdge(dut.tx_phy_clk[0])
        dut.rx_parallel_data.value = dut.tx_parallel_data.value


@cocotb.test()
async def test_loopback(dut):
    dut._log.setLevel("DEBUG")

    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    iters = 10000

    cocotb.start_soon(Clock(dut.core_clk, 66, units="ps").start())
    for i in range(4):
        cocotb.start_soon(Clock(dut.tx_phy_clk[i], 32, units="ps").start())
        cocotb.start_soon(Clock(dut.rx_phy_clk[i], 32, units="ps").start())
    await reset(dut)
    cocotb.start_soon(loopback(dut))

    await ClockCycles(dut.core_clk, 2**16)


#@cocotb.test()
async def test_pcs_tx(dut):
    dut._log.setLevel("DEBUG")

    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    iters = 10000
    ref_fifo = Queue()

    cocotb.start_soon(Clock(dut.core_clk, 66, units="ps").start())
    for i in range(4):
        cocotb.start_soon(Clock(dut.tx_phy_clk[i], 32, units="ps").start())
    await reset(dut)

    await ClockCycles(dut.core_clk, 50)

    dut.tx_data_valid.value = 1
    for _ in range(iters):
        while not dut.tx_data_ready:
            await RisingEdge(dut.core_clk)

        dut.tx_data.value = random.getrandbits(256)
        await RisingEdge(dut.core_clk)

    