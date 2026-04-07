# RTL File Overview

This document summarizes the purpose of each `.v` file under `rtl/` in the current AD7626 and Spartan-6 FPGA project.

At the moment, the RTL files are still mostly empty. The descriptions below therefore reflect the recommended module responsibilities for this project, so the document can be used as a design guide while the implementation is being completed.

## Module Relationship

The recommended signal flow is:

`top.v`
-> `ad7626_ctrl.v`
-> `ad7626_data_acquire.v`
-> optional FIFO or downstream processing

In this split:

- `top.v` is responsible for top-level integration and pin connections.
- `ad7626_ctrl.v` is responsible for ADC conversion and read timing control.
- `ad7626_data_acquire.v` is responsible for sampling ADC output data and assembling complete digital words.

## File Descriptions

### `rtl/top.v`

Top-level module for the whole FPGA design.

Suggested responsibilities:

- Define the external FPGA ports connected to the AD7626 and board-level resources.
- Instantiate lower-level RTL modules such as the ADC controller and data acquisition path.
- Connect clocks, reset, start/enable signals, and sampled data outputs.
- Provide a clean integration point for future modules such as FIFO, UART, memory interface, or debug signals.

This file should stay relatively light. It is best used for wiring and integration rather than placing all timing logic directly inside it.

### `rtl/ad7626_ctrl.v`

Control module for the AD7626 conversion and read sequence.

Suggested responsibilities:

- Generate the `CNV` conversion start pulse for the ADC.
- Wait for the required conversion time.
- Control the read sequence after conversion completes.
- Generate enable or timing signals for the data acquisition module.
- Indicate when one sampling transaction starts and ends.

Typical internal contents:

- A finite state machine, for example `IDLE`, `CNV_PULSE`, `WAIT_CONV`, `READ_DATA`, and `DONE`.
- Timing counters used to satisfy AD7626 datasheet requirements.
- Control outputs such as read enable, shift enable, bit count reset, or sample done flags.

This module answers the question: "When should the ADC convert, and when should the FPGA read the result?"

### `rtl/ad7626_data_acquire.v`

Data acquisition module for capturing ADC output bits and building a complete sample word.

Suggested responsibilities:

- Sample the ADC output pins at the correct clock edge or enable window.
- Shift serial bits into a register, or latch a parallel data bus if a parallel interface is used.
- Count the number of bits captured for one conversion result.
- Output one complete sample word such as `sample_data`.
- Raise a `sample_valid` pulse when a full sample has been assembled.

Typical internal contents:

- Shift register or latch register.
- Bit counter.
- Output register for completed ADC data.
- Data-valid generation logic.

This module answers the question: "What data was read from the ADC during this conversion?"

## Recommended Future Modules

As the project grows, the following additional files would be helpful:

### `rtl/sample_fifo.v`

Optional buffer between the ADC acquisition path and downstream logic.

Use cases:

- Prevent data loss when downstream logic is temporarily slower than the ADC sampling path.
- Isolate different clock domains.
- Simplify later integration with communication or storage modules.

### `rtl/clk_rst_mgr.v`

Clock and reset management.

Use cases:

- Generate internal clocks for control and read timing.
- Synchronize reset signals.
- Contain Spartan-6 clocking resources such as DCM or PLL instances if needed.

## Current Status

Current RTL files found in the repository:

- `rtl/top.v`
- `rtl/ad7626_ctrl.v`
- `rtl/ad7626_data_acquire.v`

These files are currently present as placeholders or early-stage skeletons. This document can serve as the baseline definition for each file before detailed implementation is added.

## Suggested Next Step

A practical next implementation order is:

1. Define the external ports in `top.v`.
2. Build the state machine in `ad7626_ctrl.v`.
3. Implement the shift/latch logic in `ad7626_data_acquire.v`.
4. Add simulation testbenches under `sim/` to verify one full conversion cycle.
