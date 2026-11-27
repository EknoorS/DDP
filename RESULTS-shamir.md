# Measured results

The baseline is the archived EC-add project corresponding to the source listings in `DDP_step_by_step.html`. The target FPGA is the PYNQ-Z2's XC7Z020. These results combine RTL co-simulation with separate FPGA technology mapping. The grading figures for the complete SoC require a routed Vivado design and a Vitis run on the board.

## Verification clocks

The table uses the actual C entry point for a valid signature. All configurations also passed their reference-point checks and rejected a one-bit-changed message after timing. Each point call uses nine Montgomery products and 12 DMA transfers. Two additional raw products perform the final projective comparison. The simulation uses Verilator 5.032 and the host DMA timing described in the measurements README.

| Course seed | Original point calls | Shamir point calls | Original clocks | Shamir only | Shamir + optimized RTL | Fewer clocks |
|---|---:|---:|---:|---:|---:|---:|
| 2026.1 | 1,135 | 814 | 38,748,911 | 27,797,346 | 25,026,546 | 35.41% |
| 2026.2 | 1,146 | 828 | 39,103,355 | 28,254,201 | 25,435,759 | 34.95% |
| 2026.3 | 1,153 | 840 | 39,373,023 | 28,681,520 | 25,822,242 | 34.42% |
| 2026.4 | 1,153 | 831 | 39,360,668 | 28,367,063 | 25,538,412 | 35.12% |
| 2026.5 | 1,108 | 796 | 37,800,003 | 27,170,700 | 24,461,154 | 35.29% |
| 2026 | 1,145 | 833 | 39,074,839 | 28,429,107 | 25,593,650 | 34.50% |

For seed **2026.1**, Shamir removes **321 point calls**, including the cost of computing G+P. Scanning both scalars together saves repeated doublings. The verifier still computes sK separately. The final version performs 7,328 Montgomery products and sends 816 commands in total. The RTL upgrade eliminates exactly **7,328 × 378 + 816 = 2,770,800** more clocks than the Shamir-only run on this seed. This reconciles the end-to-end change with the state machines.

## Which waits disappeared

| Change | Timing effect |
|---|---|
| Montgomery merged shift | Shifts A and C and advances the bit counter on the edge that completes ADD_M. Saves 377 clocks per product. |
| Montgomery startup | Loads A, clears C and initializes the counter on the start edge. Saves one more clock per product. |
| DMA-to-engine handoff | The edge accepting the final DMA word also starts the engine. FETCH uses the registered last operand on the following edge. Saves one clock per command. |
| Required completion signals | The 64-bit adder needs six chunk-processing clocks and a result acknowledgement. A one-bit `issued` flag prevents a repeated start. DMA completion still controls each load/write and the CPU can poll DONE. |

Icarus RTL simulation matched the independent integer reference on **66 of 66** operand triples. Each product took **378 fewer clocks**. Vector 0, using G_X and G_Y, took **3,758 → 3,380**. The public operand-dependent schedule explains why absolute product latency differs between vectors.

## Flexibility and FPGA resources

Yosys 0.52 mapped the ecdsa kernel, including its command/DMA controller, point engine, Montgomery multiplier and add/sub logic. LUT counts below are **logic LUT primitives**. Each row also uses 189 RAM32M distributed-memory primitives, reported separately. The course AXI interfacer, processing system and interconnect sit outside this top.

| Hardware configuration | Commands available | FFs | Logic LUTs | CARRY4 |
|---|---|---:|---:|---:|
| Original EC-add project | Point add and raw product with a programmable modulus | 7,213 | 5,362 | 106 |
| Optimized, point-only | Point add/double on the course curve | 6,091 | 4,080 | 90 |
| Optimized, fixed q | Point add/double and standalone product modulo q | 6,092 | 4,128 | 90 |
| **Optimized, flexible** | **Point add/double and standalone product with a programmable odd modulus** | **6,501** | **4,923** | **90** |

Exposing a raw product on the existing field costs **1 FF and 48 logic LUTs** over the point-only profile in this mapping. Enabling an arbitrary supported modulus adds another **409 FFs and 795 logic LUTs** over fixed q. The 409 FF increment matches one 377-bit modulus plus its 32-bit DMA address. Enabling the signing application on the flexible image adds **0 FPGA FFs and 0 LUTs**. Both applications execute on the same image.

The fixed-q profile passes the full course verifier. The point-only profile passed a CSR/DMA test for distinct-point addition and doubling and stayed idle for a standalone-product command. A point-only application would need another way to calculate the two terminal field products. This profile is an area experiment.

During optimization, restricting the curve add/sub unit to q removed **710 mapped FFs** from the merged, programmable-modulus design. Only the Montgomery unit needs the selected modulus. The final flexible kernel uses **712 fewer FFs** than the original flexible kernel.

## Delay–area product

At an assumed common 100 MHz fabric clock, seed 2026.1 takes **387.49 ms → 250.27 ms** in the simulation. Using mapped logic LUTs as the area measure gives **2,077.72 → 1,232.06 LUT·s**, a **40.7% reduction**. Using flip-flops instead gives a **41.8% reduction**. These are kernel-level comparisons with modeled interface timing. Use whole-project post-route utilization, achieved board frequency and the ARM-measured verification time for the course result.

## Signing check

The public demo fixture exercises the FPGA under both primes. It derives the nonce point and public key, computes affine x and the signature, matches r and s against independently generated expected values, then accepts the original digest and rejects an altered one. The timed verification on seed 2026.1 counted **25,026,546 simulated clocks** with the demo disabled and enabled. The extra work appears after the timing line.

## Sources used

- Hankerson, Menezes and Vanstone, *Guide to Elliptic Curve Cryptography*, §3.3.3, Algorithm 3.48. Source for simultaneous multiple-point multiplication. [Book DOI](https://doi.org/10.1007/b97644)
- Kabin, Dyka and Langendoerfer, *Atomicity and Regularity Principles Do Not Ensure Full Resistance of ECC Designs against Single-Trace Attacks*, Sensors, 2022, §2.1 and Appendix A. Hardware/software precedent for applying Straus–Shamir to signature verification. [Paper DOI](https://doi.org/10.3390/s22083083)
- NIST, *Digital Signature Standard*, FIPS 186-5, §6.4.1. Reference for the signing equations. The course Python sources supply the curve, the extended-coordinate conventions and the course-format oracle. [Standard](https://doi.org/10.6028/NIST.FIPS.186-5)
- KU Leuven DDP, *ECDSA Project*, slides 14, 18–20 and 24, and *Montgomery Multiplication in Verilog*. The cycle reductions come from inspection of your RTL and the A/B simulations. The implementation retains the original radix-2 arithmetic.
