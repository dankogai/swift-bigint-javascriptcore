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

`BigFloat` is hard-wired to BigNum's `BigInt` internally, so it is not
re-parameterized — but conversions flow freely in both directions
through the `BinaryInteger` machinery, which is the point of `JSBigInt`
being a full `SignedInteger`.

[dankogai/swift-bignum]: https://github.com/dankogai/swift-bignum
