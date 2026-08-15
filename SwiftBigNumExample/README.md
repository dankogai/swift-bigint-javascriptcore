# SwiftBigNumExample

[dankogai/swift-bignum] with its `BigInt` swapped for `JSBigInt` — while
`BigRat` and `BigFloat` keep working, side by side.

```sh
swift run
```

Three tricks make it work:

1. **The swap is one line.** A same-module declaration shadows the
   `BigInt` that `import BigNum` brings in:

   ```swift
   typealias BigInt = JSBigInt
   ```

2. **BigNum's own `BigInt` stays reachable** — not as `BigNum.BigInt`
   (the `BigNum` *protocol* shadows the module name in qualified
   lookup), but through an associated type that never stopped pointing
   at it:

   ```swift
   typealias BNBigInt = BigFloat.Significand
   ```

3. **`Rational` is generic over `RationalElement`**, so JSBigInt can be
   its element — `BigRat`'s own machinery running on JavaScriptCore
   digits:

   ```swift
   extension JSBigInt: @retroactive RationalElement {}
   typealias JSRat = Rational<JSBigInt>   // BigInt(1).over(BigInt(3)) just works
   ```

4. **`BigFloat` went generic too** ([swift-bignum#31]): it is now
   `BigFloatOf<IntType>` with `BigFloat = BigFloatOf<BigInt>`, so one
   more conformance puts a JavaScriptCore mantissa under the float —
   and π, √2 and e at any precision come out digit-for-digit identical
   to `BigFloat`'s:

   ```swift
   extension JSBigInt: @retroactive BigIntegerType {
       public var isZero: Bool { self == 0 }
   }
   typealias JSFloat = BigFloatOf<JSBigInt>
   JSFloat.PI(precision: 192)   // 3.14159265358979323846…, every digit a JS BigInt's
   ```

Conversions also flow freely in both directions through the
`BinaryInteger` machinery, which is the point of `JSBigInt` being a
full `SignedInteger`.

[dankogai/swift-bignum]: https://github.com/dankogai/swift-bignum
[swift-bignum#31]: https://github.com/dankogai/swift-bignum/pull/31
