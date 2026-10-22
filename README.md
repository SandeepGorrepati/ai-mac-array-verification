# Signed matrix MAC verification

![Matrix regression](https://github.com/SandeepGorrepati/ai-mac-array-verification/actions/workflows/regression.yml/badge.svg)
![RTL lint](https://github.com/SandeepGorrepati/ai-mac-array-verification/actions/workflows/lint.yml/badge.svg)

A two-stage signed matrix-multiply datapath with per-element saturation flags. The default configuration multiplies two 4x4 int8 matrices, accumulates in 20 bits, and clips each result to int16. It accepts valid inputs on consecutive cycles; there is no ready/backpressure input.

This is a small parallel matrix compute block, not a systolic array, GPU tensor core, or complete AI accelerator.

## Reproduce with free tools

Python 3 and Icarus Verilog are sufficient:

```bash
mkdir -p build
iverilog -g2012 -s tb_mac_array -o build/directed rtl/mac_array_4x4.sv tb/tb_mac_array.sv
vvp build/directed
iverilog -g2012 -s tb_mac_cov -o build/coverage rtl/mac_array_4x4.sv tb/tb_mac_cov.sv
vvp build/coverage
python3 scripts/gen_stream.py --n 4 --width 16
iverilog -g2012 -s tb_stream -o build/stream rtl/mac_array_4x4.sv tb/tb_stream.sv
vvp build/stream
```

GitHub Actions also sweeps N=1,2,4 and OUT_W=8,16, with IN_W=8 and ACC_W=20. This verifies six configurations, not all combinations of parameters.

## Evidence

| Layer | Observed result |
|---|---|
| Directed + random SV scoreboard | 65 passes, zero failures |
| Separate manual coverage run | 66 passes, zero failures; 11 defined bins hit |
| Independent Python-to-RTL stream | 400 cycles/configuration; 337 result matrices checked/configuration |
| Parameter sweep | Six configurations; 2,022 matrix comparisons in total |

The Python generator computes signed products, clipping, overflow flags, and packing independently. The streaming test checks every output element and flag, expected valid latency, input bubbles, continuous traffic, reset cancellation, and pipeline drain. Directed large positive/negative values exercise saturation.

11/11 means the defined saturation/sign bins and cross were hit; it does not mean exhaustive verification, code coverage, or coverage of every output element/value combination. The 65-test and 66-test runs are separate tests, not one combined run.

## Fixes and limits

The original RTL exposed OUT_W as a parameter but hard-coded 16-bit saturation thresholds and clipped constants. Limits now derive from OUT_W. Scoreboard failures and timeouts now terminate with nonzero status.

ACC_W must be large enough for the exact sum of N signed IN_W-bit products. Only the six listed configurations are validated. There is no quantization scale, accumulator reuse, AXI integration, synthesis/timing/area result, or training/inference workload claim. The older `model/mac_ref.py` self-test remains separate; `scripts/gen_stream.py` is the oracle connected to RTL execution.

See [upgrade validation](proof/UPGRADE_VALIDATION.md) and the Actions logs for evidence.
