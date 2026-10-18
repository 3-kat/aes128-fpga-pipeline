# AES-128 Pipelined Encryption Core (FPGA)

A fully unrolled, pipelined AES-128 encryption core in SystemVerilog, targeting a Xilinx Zynq-7020 (PYNQ-Z2). The goal is one 128-bit block per clock cycle, with an AXI4-Stream wrapper for DMA integration.

> **Status: work in progress.** The RTL is written but not yet verified or implemented. No timing, utilization or throughput results are reported here until they come from Vivado reports and simulation.

## Architecture

- **Datapath:** initial AddRoundKey, rounds 1-9 (SubBytes, ShiftRows, MixColumns, AddRoundKey) and a final round without MixColumns, each as its own pipeline stage.
- **Control:** a valid bit travels with the data through every stage (`iReady` in, `oValid` out). There is no stall path, so the core accepts one block per cycle.
- **Key schedule:** pipelined, one expanded word per `KeyExp1Enc` stage, with the Rcon constants in a small ROM.
- **S-boxes:** dual-port BRAM ROMs (`rom8x256dp`), two lookups per BRAM. A combinational LUT S-box (`SboxEnc`) is kept in `archive/` for comparison.
- **Byte order:** column-major, with byte (0,0) at the top bits of the 128-bit block.

## Repository layout

```
rtl/
  top/           AES_core (top level), InputRegsEnc
  round/         Round, FinalRound, SubByteEnc, ShiftRowsEnc,
                 MixColumnsEnc, MapColumn, PolyMultx2, AddRoundKeyEnc
  keyschedule/   KeyExpInit, KeyExpBlock, KeyExp1Enc, rom (Rcon)
  common/        rom8x256dp (dual-port S-box ROM)
  axi/           AXI4-Stream slave (draft, not yet functional)
archive/
  iterative_arch/  earlier iterative (non-unrolled) versions and LUT S-box
tb/              testbenches (to be added)
sim/             simulation scripts and vectors (to be added)
constraints/     XDC files (to be added)
docs/            reports and notes (to be added)
scripts/         Vivado Tcl flow (to be added)
```

## Status

| Item | State |
|---|---|
| Round datapath RTL | Written, unverified |
| Pipelined key schedule RTL | Written, unverified |
| Known-answer testbench (FIPS-197 vectors) | Not started |
| AXI4-Stream wrapper | Draft, not functional |
| Synthesis and place-and-route | Not run |
| Timing, utilization, throughput | Not measured |
| LUT vs BRAM S-box comparison | Not started |

## Roadmap

1. Testbench with the FIPS-197 Appendix B and C known-answer vectors, plus a random check against a software model.
2. Verify pipeline latency and valid alignment between the round and key-schedule paths.
3. Vivado synthesis and implementation with a 200 MHz target, then report post-route timing and utilization.
4. Rewrite the AXI4-Stream wrapper (width conversion, output FIFO, credit-based backpressure).
5. Measure core throughput and end-to-end DMA throughput separately.

## Build notes

Add everything under `rtl/` to a Vivado project, with `AES_core` as the top module. Files in `archive/` are not part of the unrolled design, so leave them out of the project.
