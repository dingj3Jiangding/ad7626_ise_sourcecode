# AD7626 Spartan-6 ISE Project

This repository contains FPGA source code for interfacing an **AD7626** ADC with a **Spartan-6 XC6LX25-2FGG484** platform using **Xilinx ISE 14.7**.

The project currently has two main roles:

1. Preserve and study the original reference implementation.
2. Build a new, easier-to-control development path for board bring-up and incremental verification.

## Current Status

The actively maintained path is under `v2/dev`.

Current progress:

1. A Day1-1 minimum digital loopback path has been built.
2. A Day1-2 minimum board-level echoed-clock path has been added.
3. Day1-2 now includes:
   - timing generation for `CNV` and burst `CLK`
   - `DCO`-based source-synchronous capture of ADC data
   - a board-top module for early bring-up
   - an early verification testbench

Current default bring-up assumptions in the new flow:

1. `tCYC = 100 ns`
2. `tCNVH = 20 ns`
3. `tMSB = 100 ns`
4. `read_start = 20 ns into the next cycle`
5. `16 x CLK @ 4 ns = 64 ns`
6. `tCLKL = 72 ns`
7. readout uses a fixed next-cycle burst slot, not a same-cycle `tMSB` wait-then-read model

## Key Files in the Current Flow

### Day1-1

1. `v2/dev/rtl/Day1-1/ad7626_min_timing_gen.v`
2. `v2/dev/rtl/Day1-1/ad7626_min_rx_core.v`
3. `v2/dev/rtl/Day1-1/ad7626_min_loopback_top.v`
4. `v2/dev/tb/tb_ad7626_min_loopback.v`

### Day1-2

1. `v2/dev/rtl/Day1-2/ad7626_day1_2_timing_gen.v`
2. `v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`
3. `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`
4. `v2/dev/tb/Day1-2/tb_ad7626_day1_2_board_top.v`
5. `v2/dev/constraints/ad7626_day1_2_board_top_template.ucf`

## Verification Status

What exists now:

1. Day1-1 loopback testbench
2. Day1-2 board-top early verification testbench
3. human-readable implementation notes
4. machine-readable handoff notes

What is still missing in this environment:

1. actual ISE synthesis/implementation verification
2. a committed one-command ISim run script for the current `v2/dev` structure
3. board-specific `LOC` assignments
4. final `sys_clk_250` generation wrapper

## Important Technical Notes

1. The target toolchain is **ISE 14.7**, so the code should stay friendly to older Verilog flows.
2. The AD7626 echoed-clock interface should be treated as a **source-synchronous** interface.
3. `D` should not be treated as ordinary fabric-synchronous data in the real hardware path.
4. The Day1-2 path currently assumes a clean external `sys_clk_250`.
5. The current Day1-2 top assumes `CNV` is implemented as a differential LVDS output pair.
