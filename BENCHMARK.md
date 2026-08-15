# Benchmark: JSCBigInt vs. attaswift/BigInt vs. swift-bignum

How does delegating to JavaScriptCore compare to pure-Swift bignums?
Short answer: **the winner depends entirely on operand size.** The
pure-Swift libraries dominate when operations are small and frequent
(the Swift ⇄ JSC bridge costs ~2 µs per call); JSCBigInt dominates once
the numbers grow past a few thousand digits, because the actual
arithmetic runs in WebKit's optimized C++ `BigInt` core.

## Environment

| | |
|:--|:--|
| Machine | Apple M1 |
| OS | macOS 26.6.1 |
| Swift | 6.3.3 (release build, `-c release`) |
| [attaswift/BigInt] | 5.7.0 |
| [dankogai/swift-bignum] | 6.3.1 |
| Date | 2026-08-15 |

[attaswift/BigInt]: https://github.com/attaswift/BigInt
[dankogai/swift-bignum]: https://github.com/dankogai/swift-bignum

## Method

The harness lives in [Benchmarks/](Benchmarks/) — a standalone package
depending on all three libraries. Each case runs the identical algorithm
on identical inputs on every side, takes the **best of 3** runs, and all
libraries' outputs are checked for agreement before timing. Results are
fed to a `@inline(never)` sink to prevent dead-code elimination.
(attaswift/BigInt and swift-bignum both name their type `BigInt`, so the
harness imports each in its own file and races them under typealiases.)

```sh
cd Benchmarks && swift run -c release bench
```

## Results

Bold marks the fastest per row; parenthesized ratios are relative to it.

| Benchmark | JSCBigInt | attaswift/BigInt | swift-bignum |
|:--|--:|--:|--:|
| sum 1...100_000 (100k small ops) | 340.02 ms (21.1×) | **16.10 ms** | 26.01 ms (1.6×) |
| fib(10_000) (2,090 digits) | 11.42 ms (4.2×) | 4.35 ms (1.6×) | **2.74 ms** |
| factorial(1_000) (2,568 digits) | 2.84 ms (8.1×) | 0.39 ms (1.1×) | **0.35 ms** |
| 2.power(100_000) (30,103 digits) | **0.01 ms** | 0.03 ms (3.5×) | 0.19 ms (22.5×) |
| 10k-digit × 10k-digit, 100 times | **24.40 ms** | 185.02 ms (7.6×) | 63.13 ms (2.6×) |
| 20k-digit ÷ 10k-digit, 100 times | **67.04 ms** | 330.91 ms (4.9×) | 183.20 ms (2.7×) |
| toString(2^100_000), decimal | 19.82 ms (1.0×) | 26.46 ms (1.4×) | **19.43 ms** |
| parse 10,000 decimal digits, 100 times | 61.15 ms (1.9×) | 93.61 ms (2.9×) | **32.15 ms** |

## Analysis

**The bridge tax is fixed; the arithmetic advantage scales.** Every
JSCBigInt operation crosses from Swift into JavaScriptCore through a
cached `JSValue` function call, costing roughly 1.5–2 µs regardless of
operand size (the 100k-small-ops case is almost pure bridge: ~340 ms for
~200k crossings). For small numbers that overhead is the whole story,
and the pure-Swift libraries — which add machine words in nanoseconds —
win by 13–21×.

As operands grow, the crossing cost stays constant while the work per
operation grows, so the balance tips:

- **fib(10_000)** and **factorial(1_000)** are transitional: thousands
  of operations on merely-thousands-of-digits numbers. The pure-Swift
  libraries still lead (swift-bignum fastest on both), but the gap
  narrows from 20× to 4–8×.
- **Multiplication and division of 10k+-digit numbers** flip the table:
  JSCBigInt beats attaswift by **7.6× / 4.9×** and swift-bignum by
  **2.6× / 2.7×**. WebKit's `JSBigInt` core uses asymptotically better
  algorithms and hand-tuned C++ limb arithmetic that pure Swift has to
  chase.
- **Radix-10 conversion** is a close race between JSCBigInt and
  swift-bignum on printing, while swift-bignum's parser is the clear
  winner — reminding us that algorithm choice matters more than
  language: attaswift, also pure Swift, trails both.
- **2.power(100_000)** is a curiosity: JSC recognizes the power-of-two
  case and effectively reduces it to a shift, finishing in microseconds.

Between the two pure-Swift libraries, swift-bignum is the faster bignum
across the board — up to ~3× on big multiplication, division, and
parsing — while attaswift takes the many-tiny-ops case where per-value
allocation dominates.

## Takeaway

If your workload is many operations on modest numbers (exponent loops,
counters, hashes), a native-Swift bignum is the right tool. If it is
fewer operations on genuinely huge numbers (10⁴+ digits), JSCBigInt's
borrowed WebKit engine is the fastest of the three — not bad for a
wrapper whose entire arithmetic layer is a dozen one-line JavaScript
functions.
