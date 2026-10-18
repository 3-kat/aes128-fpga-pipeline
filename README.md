# AES-128 Pipelined Encryption Core (FPGA)

A fully unrolled, pipelined AES-128 encryption core in SystemVerilog, targeting a Xilinx Zynq-7020 (PYNQ-Z2). The goal is one 128-bit block per clock cycle, with an AXI4-Stream wrapper for DMA integration.

> **Status: work in progress.** The RTL is written and passes one FIPS-197 known-answer vector in simulation. It has not been implemented in Vivado yet. No timing, utilization or throughput results are reported here until they come from Vivado reports.

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
tb/              per-module testbenches and tb_AES_core
sim/             aes_ref.py, a software AES-128 reference (round keys and per-round states)
constraints/     XDC files (to be added)
docs/            reports and notes (to be added)
scripts/         Vivado Tcl flow (to be added)
```

## Status

| Item | State |
|---|---|
| Round datapath RTL | Written; per-module testbenches plus the C.1 vector pass in simulation |
| Pipelined key schedule RTL | Written; all 11 round keys match a software reference for key `000102...0f` |
| Known-answer testbench (FIPS-197 vectors) | One vector (Appendix C.1) in `tb_AES_core`; more vectors to add |
| AXI4-Stream wrapper | Draft, not functional |
| Synthesis and place-and-route | Not run |
| Timing, utilization, throughput | Not measured |
| LUT vs BRAM S-box comparison | Not started |

## Known issues

- `KeyExp1Enc`: `InterKey` takes the current input word (`iNkKeys[31:0]`) while `OldKeys` is the registered copy. The core is correct for a key that is held constant, at one block per clock. If the key changes from one block to the next, the round keys are wrong. Using `OldKeys[31:0]` instead was tested in simulation and fixes it, but is not applied yet.
- The AXI4-Stream slave is a draft and does not deliver data to the core.

## Roadmap

1. Testbench with the FIPS-197 Appendix B and C known-answer vectors, plus a random check against a software model.
2. Verify pipeline latency and valid alignment between the round and key-schedule paths.
3. Vivado synthesis and implementation with a 200 MHz target, then report post-route timing and utilization.
4. Rewrite the AXI4-Stream wrapper (width conversion, output FIFO, credit-based backpressure).
5. Measure core throughput and end-to-end DMA throughput separately.

## Build notes

Add everything under `rtl/` to a Vivado project, with `AES_core` as the top module. Files in `archive/` are not part of the unrolled design, so leave them out of the project.
