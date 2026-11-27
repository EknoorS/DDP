# DDP verification upgrade and signing demo

Use this source overlay with the working **EC-add** project from `DDP_step_by_step.html` or `DDP_EC_Hardware.zip`. Keep a copy of your working project for the comparison. This package contains the seven changed or new source files and the measurement tools.

## 1. Install it

1. Close your editors and copy the contents of `hw_project/` and `sw_project/` from this ZIP over those folders in your project copy. Both sit directly under your course `package/` directory.
2. In **Vivado → Sources**, check the source paths for `ecdsa`, `ec_add` and `montgomery`. They should point at the three files listed below. If Vivado imported local copies, replace the contents of those existing design sources. Keep one definition of each module. Keep the original `adder.v`, `modadder.v`, `interfacer.v` and the EC wrapper testbench.
3. Run behavioral simulation with the existing `tb_ecdsa_wrapper` as simulation top. Run all and check for `ALL RTL TESTS PASSED`. Build the **whole** `ecdsa_project_wrapper` bitstream at your baseline clock (course default 100 MHz); inspect timing, then export an XSA including that bitstream. Leave `VARIABLE_MODULUS=1` and `POINT_ONLY=0` for the application.
4. In **Vitis**, update the platform to that XSA and build it. Under the same application source folder as `ec.c`, include the new `signing_demo.c`. If the workspace uses imported source copies, replace `main.c`, `accelerator.c`, and `ec.c` there too. The header `ec.h` from the working EC-add project already has the required declarations. Build and launch the application with the new bitstream.
5. For the reported seed, run `python3 testvectors.py ECDSA_verify 2026.1` inside the course `testvectors/` directory of your project copy and rebuild the application. The generator writes `sw_project/src/sw/testvector.c`. Repeat for seeds ending in .2 through .5. Keep the bitstream for all five.

| File relative to your project | What changed |
|---|---|
| `hw_project/src/rtl/montgomery/montgomery.v` | Initializes on the accepted start edge. Commits the right shifts and advances the bit counter on completion of `ADD_M`. |
| `hw_project/src/rtl/ecdsa/ecdsa.v` | Starts the point engine when the final DMA operand arrives. Selects the modulus profile and advertises the build ID. |
| `hw_project/src/rtl/ecdsa/ec_add.v` | Supplies the fixed curve field to the modular add/sub unit. The single shared Montgomery multiplier retains the programmable modulus. |
| `sw_project/src/sw/ec.c` | Computes the verifier's left side with Shamir's joint scalar loop. |
| `sw_project/src/sw/accelerator.c` | Recognizes the new hardware revision. The fixed-field comparison profile rejects requests with a different modulus. |
| `sw_project/src/sw/main.c` | Times verification and checks equivalent projective points. Reads the demo switch after the timed section and regression checks. |
| `sw_project/src/sw/signing_demo.c` | Signs the public classroom fixture, checks against the course Python oracle, verifies the signature and rejects an altered digest. |

## 2. Show the two applications with one ELF and bitstream

**Verification.** Leave `demo_enabled` at 0. On UART you should see the smoke test, the course `>>> TIMING` line, the reference-point check, and `PASS: changed message rejected.` The timer surrounds one `verify_signature()` call. Point comparisons, printing, negative tests, and signing run outside the measured interval.

**Signing.** Set a breakpoint at the start of `run()` in `main.c`. Start the same ELF on the same programmed board, stop at the breakpoint, and set the global `demo_enabled` to 1 in **Vitis → Expressions**. Resume. You can also set the initializer default with `#define RUN_SIGNING_DEMO 1` in `main.c` if you prefer a demo ELF. The expected final line is:

```text
DEMO PASS: r and s match Python, signature accepted, changed digest rejected.
```

The ARM builds the public key $P=dG$ and nonce point $K=kG$ via repeated **command 2** point operations. It recovers affine $x=X/Z$ in the field $q$ and reduces it modulo the group order $n$ to obtain $r$. It computes $s=k^{-1}(m+dr)\bmod n$. The signer sends modular products and the inversion products to **command 1**, with the appropriate modulus. The ARM handles bit loops, small additions, reduction to the group order, and driver calls. The FPGA always uses $R=2^{377}$, including when the modulus has 253 bits.

The demo uses a single fixed digest, a published test key and a published test nonce. Those choices make the reference signature reproducible. Signing a real message requires secret nonce handling and a side-channel-reviewed implementation. The application implements the **course signature format** `(K, s)` and its supplied verifier convention.

## 3. Measure the figures for the course

Keep the board clock, Vivado settings, ARM build flags, and seed identical across runs. In a separate baseline project copy use the original C and RTL. For a Shamir-only board comparison, use the new `ec.c`, `main.c`, and `signing_demo.c` with the original RTL **and original accelerator.c**. That original driver recognizes the old interface ID. For the final build use all seven files.

With the implemented top open, source `measurements/board_reports.tcl` in the Vivado Tcl console. It writes area, hierarchy, and timing reports in `ddp_measurements/` under the Vivado project. Record whole-project **Slice LUTs**, **registers used as flip-flops**, and setup/hold timing. Compare end-to-end ARM counter values from Vitis. Convert those counter values with their ARM counter frequency. The desktop results in `RESULTS.md` give you a comparison to check against before the board run.

The additional area profiles are optional synthesis experiments. In an isolated project copy set `VARIABLE_MODULUS=0, POINT_ONLY=0` on the `ecdsa` module reference to measure fixed-$q$ verification. Setting `VARIABLE_MODULUS=0, POINT_ONLY=1` exposes only point addition. Rebuild each profile independently. The supplied Vitis verifier needs command 1 for its final two products, so use the point-only design for area comparison or its point-add benchmark.
