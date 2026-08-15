# swift-bigint-javascriptcore

BigInt Implementation via JavaScriptCore

Every Apple OS ships with [JavaScriptCore], and its JS engine has native
arbitrary-precision `BigInt`.  `JSBigInt` wraps a `JSValue` holding a JS
`BigInt` and delegates all arithmetic to a shared `JSContext` with
pre-compiled helper functions — arbitrary-precision integers with zero
dependencies beyond the OS.

[JavaScriptCore]: https://developer.apple.com/documentation/javascriptcore

## Synopsis

```swift
import JSCBigInt

// Integer literals of any size, thanks to StaticBigInt
let n: JSBigInt = 123456789012345678901234567890123456789012345678901234567890

// A full SignedInteger: use it like any Swift integer
let fact100 = (1...100).map { JSBigInt($0) }.reduce(1, *)
JSBigInt(2).power(128)              // 340282366920938463463374607431768211456
(JSBigInt(1) << 100) >> 100         // 1
JSBigInt("deadbeef", radix: 16)!    // 3735928559
fact100.toString(radix: 36)         // "1cnfrwcnvxbzzicfd6…"
Int(JSBigInt(42))                   // 42 — stdlib conversions just work
Double(JSBigInt(1) << 100)          // 1.2676506002282294e+30
```

## Usage

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/dankogai/swift-bigint-javascriptcore.git", branch: "main")
```

and `import JSCBigInt`.

## Features

- `JSBigInt` conforms to `SignedInteger` (hence `BinaryInteger`, `Numeric`,
  `Comparable`, `Hashable`, `Strideable`…), so it works with generic
  integer algorithms out of the box.
- Integer literals use `StaticBigInt` — no precision loss, no strings needed.
- Swift semantics throughout: `/` truncates toward zero, `%` takes the
  dividend's sign, `>>` is an arithmetic (smart) shift, division by zero traps.
- String conversion to and from any radix in `2...36`.
- Exact conversions to and from `BinaryInteger` and `BinaryFloatingPoint`
  types, including two's-complement `words` for stdlib interop.
- `power(_:)` via the JS `**` operator, and modular exponentiation
  `power(_:mod:)` with swift-bignum-compatible semantics (least
  non-negative residue; a negative exponent takes the modular inverse).
- `greatestCommonDivisor(with:)` and `squareRoot()` (integer square
  root, floor), named and behaving like their swift-bignum and
  attaswift/BigInt counterparts.
- Miller-Rabin primality: `isPrime` is tri-state à la swift-bignum —
  `false` and `true` are proofs (deterministic below [A014233]'s last
  entry, ≈3.3 × 10²⁴), `nil` means "probably prime, unproven" with
  `isProbablePrime` holding that opinion; `millerRabinTest(base:)`
  exposes a single round.  `nextPrime`/`prevPrime` walk to the
  neighboring primes (on the probable test, so they terminate at any
  size), each walk in a single bridge crossing.

[A014233]: https://oeis.org/A014233
- `Codable` (encoded as a decimal string).
- Thread-safe: values are immutable and JavaScriptCore serializes access
  through the `JSVirtualMachine` lock.

## Caveats

- Apple platforms only (macOS, iOS, tvOS, visionOS). No Linux, no watchOS —
  they lack JavaScriptCore.
- Every operation crosses the Swift ⇄ JavaScriptCore bridge, so it is not a
  speed demon for many small operations.  Large-number performance is
  excellent, though — for 10k-digit multiplication it beats the pure-Swift
  bignum libraries (attaswift/BigInt, dankogai/swift-bignum) severalfold,
  since the heavy lifting happens inside JSC's optimized `BigInt`.
  See [BENCHMARK.md](BENCHMARK.md) for numbers.
- For serious work, consider [attaswift/BigInt] or [dankogai/swift-bignum];
  this package is a proof of concept that happens to be practical.

[attaswift/BigInt]: https://github.com/attaswift/BigInt
[dankogai/swift-bignum]: https://github.com/dankogai/swift-bignum

## Prerequisite

Swift 5.9 or better, macOS 14 / iOS 17 or later.

## License

MIT. See [LICENSE](LICENSE).
