import cocotb
import random
import time
from cocotb.triggers import Timer, ReadOnly, ReadWrite, ClockCycles, RisingEdge, FallingEdge
from cocotb.clock import Clock

state = 0
def scramble_block(payload):
    global state
    scrambled = 0
    for i in range(256):
        in_bit = (payload >> i) & 1
        tap = ((state >> 57) & 1) ^ ((state >> 38) & 1)
        out_bit = in_bit ^ tap
        scrambled |= (out_bit << i)
        # shift in scrambled output bit
        state = ((state << 1) & ((1 << 58) - 1)) | out_bit
    return scrambled


@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await ClockCycles(dut.clk, 5)
    dut.reset.value = 0
    print("DUT reset")


@cocotb.test()
async def test_scrambler(dut):
    seed = int(time.time())
    random.seed(seed)
    print(f"using seed: {seed}")

    cocotb.start_soon(Clock(dut.clk, 2, units="ps").start())
    await reset(dut)

    dut.en.value = 1

    global state
    for _ in range(10000):
        block = random.getrandbits(256)
        ref_scram = scramble_block(block)

        dut.data_in.value = block
        await RisingEdge(dut.clk)

        assert dut.data_out.value == ref_scram, f"Sim data {hex(dut.data_out.value)} =/= ref data {hex(ref_scram)}"
