# Faster verification on the DDP Shamir project

This is a one-file hardware upgrade for the working DDP Shamir design. Both the verifier and the signing demo use the same new multiplier.

## Try it in Vivado and Vitis

1. Make a copy of your working Shamir project. In the copy, open the existing design source for the module named `montgomery` and replace it with `hw_project/src/rtl/montgomery/montgomery.v` from this ZIP. Check the path under **Source File Properties** if Vivado uses an imported copy. The module connects to your existing `adder.v`. Keep one definition of `montgomery`.
2. For a quick check, add `optional_sim/tb_fast_montgomery.v` under **Simulation Sources**, select it as the simulation top, and run behavioral simulation → **Run All**. Its three expected start-to-done latencies are **116, 103, 103**. For the system check, switch the simulation top back to `tb_ecdsa_wrapper` and run all.
3. Implement the complete `ecdsa_project_wrapper` at the same clock as your previous build. Review the routed timing summary for setup and hold. The 13-bit lane multiply-add path, signal routing, and DSP placement matter for the 100 MHz target.
4. Generate the new bitstream and export the XSA **with bitstream**. Update your Vitis platform and program the FPGA with this build. The software interface ID is identical to the Shamir version, so the ID check alone also accepts the older, slower image. Check the selected bitstream path and the UART timing.
5. Use the previous Vitis application and course vector for `ECDSA_verify 2026.1`. The UART `>>> TIMING` line measures verification from software. As before, `demo_enabled=1` runs signing after the timed call. Collect whole-project LUT, FF, DSP and timing reports from this implementation.

## What happens inside

The old design scanned one bit and sometimes invoked the six-chunk adder twice for that bit. The new design splits both 377-bit operands into **29 digits of 13 bits**. Each cycle that processes a product operates on all 29 digits of B or M in parallel. The 29 small multipliers are reused between these two jobs.

Let the base be D = 8192 = 2^13. For one digit a of the first operand, the controller:

1. Computes U = T + aB. Each lane handles its own digit and local carry.
2. Chooses a correction digit c so U + cM has a zero low digit. For both course moduli, M mod D = 1, so c = −U mod D. For example, if U ends in digit 5, use c = 8187. Then the low digit of 5 + 8187M is zero.
3. Adds cM using the same multiplier lanes. Dividing by D is now an exact digit shift. Wiring the overlapping pieces into the next round avoids a 377-bit carry chain in this loop.

After 29 rounds, D^29 = 2^377, exactly the Montgomery factor the rest of your project expects. The controller combines the local carries and conditionally subtracts the modulus using the existing wide adder. Reduced inputs satisfy A,B < M; the running value stays below 2M, so one final subtraction suffices. B and M must stay stable through the operation as in the previous design.

For any other supported odd M, the hardware can compute mu = −M^(-1) mod D in 13 setup clocks. It then obtains each correction as c = (U mod D) × mu mod D. Odd moduli ending in the digit 1 use the short path automatically.

## What was measured

| Metric | Previous Shamir | New multiplier |
|---|---:|---:|
| Verification, seed 2026.1, simulated FPGA clocks | 25,026,546 | 909,769 |
| Standalone course multiplication vector, seed 2026.1, RTL clocks | 3,338 | 116 |
| G_X × G_Y Montgomery product using curve q, RTL clocks | 3,380 | 103 |
| Mapped kernel flip-flops | 6,501 | 6,943 |
| Mapped kernel logic LUT primitives | 4,923 | 5,456 |
| DSP48E1 | 0 | 30 |
| RAM32M distributed memory primitives | 189 | 189 |

The 103 clocks are 29 three-cycle rounds plus 16 clocks for normalization and final subtraction. Generic moduli add 13 initialization clocks. The kernel mapping used Yosys 0.52, `synth_xilinx -family xc7 -flatten -noiopad -noclkbuf`, with top `ecdsa`. LUT counts sum the LUT1–LUT6 primitives, with RAM32M reported separately. The 30 DSPs cover 29 digit lanes plus one low-digit multiplication for generic moduli.

| Seed | Timed point calls | New simulated FPGA clocks |
|---|---:|---:|
| 2026.1 | 814 | 909,769 |
| 2026.2 | 828 | 925,673 |
| 2026.3 | 840 | 937,884 |
| 2026.4 | 831 | 929,683 |
| 2026.5 | 796 | 889,804 |

All five course vectors passed the intermediate-point checks and accepted their valid signatures. The program rejected the changed messages and passed the signing demo. The full verifier ran as compiled C against simulated Verilog using the previous Shamir package's Verilator harness and modeled DMA. The existing CSR/DMA testbench passed in Icarus, as did the original 66-vector arithmetic regression and an additional 1,025-vector suite covering the graded vector, small and full-size odd moduli, and operands near the modulus.

## Reading the class spreadsheet

The class verification column asks for the **ARM-measured cycles from Vitis**. The simulation reports FPGA clock edges with a host driver and a simple DMA model. At 100 MHz, 909,769 FPGA clocks represent 9.10 ms in that model. The supplied block design configures the ARM at 650 MHz and the FPGA at 100 MHz, and the supplied performance counter counts each ARM cycle. The same 9.10 ms spans roughly 5.91 million ARM clocks. The physical board also introduces its actual command, cache, bus and memory costs. Record the UART measurement for your spreadsheet row.

For a sub-million ARM target at those clocks, the entire verifier has about 153,846 FPGA clocks of elapsed time. Your current schedule executes 7,328 Montgomery products serially on seed 2026.1. Even the 103 clocks of arithmetic per product already total 754,784 FPGA clocks. A subsequent design would need substantial overlap between independent coordinate products or fewer products, and a coarse-grained interface that keeps points on the FPGA. The CPU and FPGA clock ratio matters whenever teams compare scores.

## Research context

- *Resource-aware Montgomery modular multiplication optimization for digital signal processing* (2024). Background on matching the Montgomery word size to FPGA DSP resources. [Paper](https://doi.org/10.1016/j.sysarc.2024.103142)
- Mert et al., *A Flexible and Scalable NTT Hardware* (DATE 2020). Their word-level reduction uses moduli of the form q = qH × 2^w + 1. Both course primes have the low-digit property needed here. The choice of 29 lanes, 13-bit digits, the general-modulus path and these measurements are specific to this DDP implementation. [Paper](https://past.date-conference.com/proceedings-archive/2020/pdf/0695.pdf)
