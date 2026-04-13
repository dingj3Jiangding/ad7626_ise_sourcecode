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

1. `tCYC = 240 ns`
2. `tCNVH = 20 ns`
3. `tMSB = 100 ns`
4. `tCLK = 4 ns`

These values are intentionally conservative for first hardware validation.

## Recommended Entry Point

If you are working on the current development flow, start here:

1. `v2/dev/README.md`
2. `v2/dev/human_doc/00_INDEX.md`
3. `v2/llm_doc/00_INDEX.md`

If you only want the current implementation files:

1. `v2/dev/rtl/Day1-1/`
2. `v2/dev/rtl/Day1-2/`
3. `v2/dev/tb/`
4. `v2/dev/constraints/`

## Directory Guide

### `v2/dev`

This is the main development area.

Use this for:

1. new RTL
2. new testbenches
3. bring-up-oriented constraints
4. human-readable design notes

Important subdirectories:

1. `v2/dev/rtl/Day1-1`
   minimum digital loopback path
2. `v2/dev/rtl/Day1-2`
   early board-level AD7626 echoed-clock path
3. `v2/dev/tb`
   testbenches for staged verification
4. `v2/dev/constraints`
   board constraint templates
5. `v2/dev/human_doc`
   code-facing notes written for human review

### `v2/ref`

This is the original reference code area.

Treat it as read-only reference.

Use it for:

1. studying module partitioning
2. checking reference timing/control ideas
3. understanding ADI-style project structure

Do not use it as the main place for new implementation work.

### `v2/ref_code_docs`

This contains code-reading notes for reference modules.

It is useful when you want to understand what a specific reference module is doing without reopening the whole hierarchy every time.

### `v2/llm_doc`

This contains machine-oriented handoff notes.

Use it when:

1. context has been lost between sessions
2. another model needs to resume work quickly
3. you want a compact summary of current project constraints and next steps

### `v1`

This is an older reference snapshot.

It is still useful for:

1. older project structure examples
2. Spartan-6 compatible patterns
3. comparing different stages of the reference flow

### `manual_rtl`

This contains hand-written exploratory RTL from an earlier stage.

It is useful as design scratch material, not as the current primary development path.

### `doc`

Older high-level notes and planning material.

Useful as background, but not the main current source of truth.

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

## Suggested Reading Order

If you are new to this repository, the fastest useful order is:

1. read `v2/dev/README.md`
2. read `v2/dev/human_doc/04_day1_pm_hw_bringup_plan.md`
3. read `v2/dev/human_doc/06_day1_2_checkpoint_design.md`
4. read `v2/llm_doc/AD7626_echoed_clock_interface_guide.md`
5. then open the Day1-2 RTL files

## Short Version

If you only remember one thing:

`v2/dev` is the current work area, `v2/ref` is reference-only, and the present bring-up focus is the Day1-2 echoed-clock path under `v2/dev/rtl/Day1-2/`.
