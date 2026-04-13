# AD7626 Echoed-Clock Interface Guide

## Scope
This guide intentionally focuses on **echoed-clock mode**, not self-clocked mode. The goal is to give another model or engineer a reusable, implementation-oriented summary of the **timing contract**, **LVDS standard**, and **FPGA integration rules** for the AD7626.

## 1. Device summary
- 16-bit SAR ADC
- 10 MSPS maximum throughput
- Differential analog input range: **±4.096 V**
- Output code: **two's-complement, MSB first**
- Digital interface: **serial LVDS**
- Supplies: **VDD1 = 5 V**, **VDD2 = 2.5 V**, **VIO = 2.5 V**

## 2. Echoed-clock mode: what it means
Echoed-clock mode is the simpler digital-readout mode for FPGA work.

It uses:
- `CLK±` : host-to-ADC burst read clock
- `DCO±` : ADC-to-host echoed clock
- `D±` : ADC-to-host serial data
- `CNV±` or `CNV+` : conversion start

Unlike self-clocked mode:
- there is **no 010 framing header**
- there is **no need for phase-search / oversampling logic**
- the host captures data with the returned `DCO`

## 3. Core timing parameters
| Item | Symbol | Value |
|---|---:|---:|
| Conversion cycle min | `tCYC` | 100 ns |
| Max idle gap between conversions | `tCYC(max idle)` | 10,000 ns |
| Acquisition time | `tACQ` | 40 ns |
| CNV high time | `tCNVH` | 10 to 40 ns |
| CNV to MSB ready | `tMSB` | 100 ns |
| CNV to last allowable read-clock boundary | `tCLKL` | 72 ns |
| CLK period | `tCLK` | 3.33 ns min |
| CLK frequency | `fCLK` | 250 to 300 MHz |
| CLK to DCO delay | `tDCO` | 0 / 4 / 7 ns min/typ/max |
| DCO to D delay | `tD` | 0 to 1 ns |
| CLK to D delay | `tCLKD` | 0 / 4 / 7 ns min/typ/max |

## 4. Exact echoed-clock timing contract
1. A **rising edge on CNV** starts conversion.
2. CNV must return low within `tCNVH`.
3. Extra CNV pulses during conversion are ignored.
4. After `tMSB = 100 ns`, the new sample is ready to be shifted out.
5. The host bursts **exactly 16 CLK pulses** into `CLK±`.
6. The ADC outputs `DCO±`, which is a buffered copy of `CLK±`.
7. The ADC updates `D±` on the **falling edge of DCO+**.
8. The host should capture `D±` on the **rising edge of DCO+**.
9. The 16 read clocks must complete before the next `tCLKL` boundary.
10. Between `tCLKL` and the next `tMSB`, `D±` and `DCO±` are driven low.
11. `CLK±` should idle low between bursts.

## 5. Important full-rate interpretation
At 10 MSPS:
- one full sample cycle is **100 ns**
- `tMSB` is also **100 ns**

So the readout of sample `N` is naturally performed during the acquisition interval of sample `N+1`. This is expected behavior.

A good mental model:
- `CNV` launches conversion `N`
- after the conversion latency, the host reads sample `N`
- meanwhile the front end is already acquiring sample `N+1`

## 6. FPGA implementation rule
Recommended capture architecture:
- one control state machine generates `CNV` and burst `CLK`
- one source-synchronous receiver captures `D` using `DCO`

Do **not** treat `D` as ordinary fabric-synchronous data unless you first bring it into a proper source-synchronous capture structure.

### Practical receive rule
- use `DCO` as the sampling clock
- sample `D` on **rising DCO+**
- shift **16 bits**
- latch the final 16-bit word after 16 captures

## 7. LVDS electrical standard
The interface follows **ANSI-644-style LVDS**.

### Relevant electrical numbers
| Parameter | Value |
|---|---|
| Data format | serial LVDS two's-complement |
| Differential output voltage `VOD` into 100 ohm | 245 / 290 / 454 mV min/typ/max |
| Output common-mode `VOCM` into 100 ohm | 980 / 1130 / 1375 mV min/typ/max |
| Differential input voltage `VID` | 100 to 650 mV |
| Common-mode input voltage `VICM` | 800 to 1575 mV |

### Practical meaning
- `D±` and `DCO±` are LVDS outputs from the ADC
- `CLK±` is an LVDS input to the ADC
- `CNV±` may also be LVDS
- alternatively `CNV+` may be driven by **2.5 V CMOS** if `CNV-` is grounded

## 8. Differential pairs required in echoed-clock mode
Minimum for echoed-clock readout:
- `D±`
- `DCO±`
- `CLK±`

Optional depending on conversion-control choice:
- `CNV±` as LVDS pair
- or single-ended `CNV+` as 2.5 V CMOS

## 9. Termination and routing implications
- The application diagram shows **100 ohm differential termination** for LVDS lines.
- The datasheet power note says echoed-clock mode dissipates **1.8 mW in two 100 ohm terminators**, implying two active LVDS receive terminations in this mode.
- `D±` and `DCO±` should be routed with **good propagation-delay matching** because timing margin depends on their alignment.
- `CLK±` should be treated as a controlled-impedance differential pair.
- Keep `CLK±` **idle low between bursts**.

## 10. Conversion control details
- Conversion always starts on the **rising edge of CNV**
- `CNV` high time must be **10 ns to 40 ns**
- If the ADC is left idle for more than **10 us**, the next conversion result is invalid
- After power-up, the **first conversion result is invalid**

## 11. Pin-level notes relevant to echoed-clock designs
| Pins | Role | Note |
|---|---|---|
| 8, 9 | `CNV-`, `CNV+` | conversion control inputs |
| 10, 11 | `D-`, `D+` | serial LVDS data outputs |
| 14, 15 | `DCO-`, `DCO+` | echoed clock outputs |
| 16, 17 | `CLK-`, `CLK+` | host burst read-clock inputs |
| 12 | `VIO` | 2.5 V digital interface supply |

## 12. Power / reference facts that still affect bring-up
Reference mode is selected by `EN1/EN0`:
- `11` : internal reference + internal buffer
- `01` : external 1.2 V on `REFIN`
- `10` : external 4.096 V on `REF`
- `00` : power-down

Wake-up from power-down:
- internal reference mode: **9.5 s**
- external 1.2 V mode: **25 ms**
- external 4.096 V mode: **65 us**

Power-up order:
1. apply `VDD2` and `VIO`
2. apply `VDD1`
3. apply reference
4. apply analog inputs

## 13. Common mistakes
- assuming echoed-clock mode has the self-clocked `010` header
- sampling `D` on the wrong edge
- sending more than 16 read clocks
- not idling `CLK` low between bursts
- stretching `CNV` high beyond 40 ns
- forgetting the 10 us maximum idle gap
- trying to ignore `DCO` and capture `D` with an unrelated FPGA clock

## 14. Condensed reusable knowledge block
**AD7626 echoed-clock mode summary:** 16-bit SAR ADC, 10 MSPS max, serial LVDS output, two's-complement, MSB first. Use CNV rising edge to start conversion; return CNV low within 10-40 ns. After `tMSB = 100 ns`, host bursts 16 LVDS CLK pulses into `CLK±`. ADC returns `DCO±` as a buffered copy of `CLK±` and drives `D±` synchronous to it. `D` updates on falling `DCO+`; host captures on rising `DCO+`. Complete all 16 clocks before the subsequent `tCLKL` boundary. Keep `CLK` idle low between bursts. Echoed-clock mode uses three LVDS pairs: `CLK±` in, `DCO±` out, `D±` out. `CNV` can be LVDS or 2.5 V CMOS on `CNV+` with `CNV-` grounded. LVDS levels are ANSI-644 style, with `VOD` about 290 mV typ into 100 ohm and `VOCM` about 1.13 V typ. Use propagation-delay matching between `D` and `DCO` and capture `D` source-synchronously in the FPGA.
