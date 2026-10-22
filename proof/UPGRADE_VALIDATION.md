# Upgrade validation - 2026-10-22

Validated code commit: 9f081ddf2df88ec898239d0c79f9d8427cce95e2. Directed 65/65; separate coverage 66/66; six stream configurations with 337 matrix checks each.

[Recorded GitHub Actions run](https://github.com/SandeepGorrepati/ai-mac-array-verification/actions/runs/39752109409). Subsequent documentation or path-filter changes do not extend the tested functionality. Re-run the workflow after code changes. Full logs are retained as Actions artifacts subject to GitHub retention limits.

## Observed log excerpts

```text
MAC-ARRAY VERIFICATION SUMMARY
  tests=65  PASS=65  FAIL=0  saturating-tests=3
  tests=66 PASS=66 FAIL=0
PASS: Python oracle cycles=400 checked=337 N=1 OUT_W=8; streaming, bubbles, reset
PASS: Python oracle cycles=400 checked=337 N=1 OUT_W=16; streaming, bubbles, reset
PASS: Python oracle cycles=400 checked=337 N=2 OUT_W=8; streaming, bubbles, reset
PASS: Python oracle cycles=400 checked=337 N=2 OUT_W=16; streaming, bubbles, reset
PASS: Python oracle cycles=400 checked=337 N=4 OUT_W=8; streaming, bubbles, reset
PASS: Python oracle cycles=400 checked=337 N=4 OUT_W=16; streaming, bubbles, reset
```

These are observed excerpts, not illustrative expected output. Passing this finite suite does not establish exhaustive correctness.

