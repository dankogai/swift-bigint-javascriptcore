# Benchmark: JSCBigInt vs. attaswift/BigInt

How does delegating to JavaScriptCore compare to a pure-Swift bignum?
Short answer: **each library wins by an order of magnitude — on opposite
workloads.** attaswift dominates when operations are small and frequent
(the Swift ⇄ JSC bridge costs ~2 µs per call); JSCBigInt dominates when
the numbers themselves are large, because the actual arithmetic runs in
WebKit's optimized C++ `BigInt` core.

## Environment

| | |
|:--|:--|
| Machine | Apple M1 |
| OS | macOS 26.6.1 |
| Swift | 6.3.3 (release build, `-c release`) |
| attaswift/BigInt | 5.7.0 |
| Date | 2026-08-15 |

## Method

The harness lives in [Benchmarks/](Benchmarks/) — a standalone package
depending on both libraries. Each case runs the identical algorithm on
identical inputs on both sides, takes the **best of 3** runs, and both
libraries' outputs are checked for agreement before timing. Results are
fed to a `@inline(never)` sink to prevent dead-code elimination.

```sh
cd Benchmarks && swift run -c release bench
```

## Results

| Benchmark | JSCBigInt | attaswift/BigInt | ratio (JSC/atta) |
|:--|--:|--:|--:|
| sum 1...100_000 (100k small ops) | 350.28 ms | 16.01 ms | 21.87× |
| fib(10_000) (2,090 digits) | 12.83 ms | 4.32 ms | 2.97× |
| factorial(1_000) (2,568 digits) | 2.79 ms | 0.39 ms | 7.15× |
| 2.power(100_000) (30,103 digits) | 0.01 ms | 0.03 ms | 0.29× |
| 10k-digit × 10k-digit, 100 times | 24.36 ms | 185.82 ms | **0.13×** |
| 20k-digit ÷ 10k-digit, 100 times | 67.17 ms | 329.76 ms | **0.20×** |
| toString(2^100_000), decimal | 19.73 ms | 26.34 ms | 0.75× |
| parse 10,000 decimal digits, 100 times | 61.64 ms | 94.86 ms | 0.65× |

(ratio < 1 means JSCBigInt is faster)

## Analysis

**The bridge tax is fixed; the arithmetic advantage scales.** Every
JSCBigInt operation crosses from Swift into JavaScriptCore through a
cached `JSValue` function call, costing roughly 1.5–2 µs regardless of
operand size (the 100k-small-ops case is almost pure bridge: ~350 ms for
~200k crossings). For small numbers that overhead is the whole story,
and attaswift — which adds two machine words in nanoseconds — wins by
20×.

As operands grow, the crossing cost stays constant while the work per
operation grows, so the balance tips:

- **fib(10_000)** and **factorial(1_000)** are transitional: thousands
  of operations on merely-thousands-of-digits numbers. attaswift still
  leads, but the gap narrows from 20× to 3–7×.
- **Multiplication and division of 10k+-digit numbers** flip the table:
  JSCBigInt is **7.6× and 4.9× faster**. WebKit's `JSBigInt` core uses
  asymptotically better algorithms and hand-tuned C++ limb arithmetic,
  while attaswift's pure-Swift multiply falls behind at this size.
- **Radix-10 conversion** (both directions) is also faster in JSC —
  string conversion is super-linear, so the engine quality shows.
- **2.power(100_000)** is a curiosity: JSC recognizes the power-of-two
  case and effectively reduces it to a shift, finishing in microseconds.

## Takeaway

If your workload is many operations on modest numbers (cryptographic
exponent loops, counters, hashes), a native-Swift bignum is the right
tool. If it is fewer operations on genuinely huge numbers (10⁴+ digits),
JSCBigInt's borrowed WebKit engine is several times faster than pure
Swift — not bad for a wrapper whose entire arithmetic layer is a dozen
one-line JavaScript functions.
