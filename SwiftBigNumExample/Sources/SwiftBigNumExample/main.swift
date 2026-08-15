//
//  swift-bignum with its BigInt swapped for JSBigInt.
//
//  The point of this example: within this module, `BigInt` IS `JSBigInt`.
//  A same-module declaration shadows the `BigInt` that `import BigNum` brings
//  in, so everything below that says `BigInt` runs on JavaScriptCore — while
//  BigNum's `BigRat` and `BigFloat` keep working, side by side.
//
import BigNum
import JSCBigInt

typealias BigInt = JSBigInt

// BigNum's own BigInt is still reachable — not as `BigNum.BigInt` (the
// `BigNum` *protocol* shadows the module name in qualified lookup), but
// through an associated type that never stopped pointing at it:
typealias BNBigInt = BigFloat.Significand

// `Rational` is generic over `RationalElement`, so JSBigInt can be its
// element: this is BigRat's own machinery running on JavaScriptCore digits.
extension JSBigInt: @retroactive RationalElement {}
typealias JSRat = Rational<JSBigInt>

func banner(_ title: String) {
    print("\n== \(title) ==")
}

// MARK: 1. `BigInt` is JSBigInt now

banner("BigInt is JSBigInt")
let fact30: BigInt = (1...30).map { BigInt($0) }.reduce(1, *)
print("type(of: fact30)  :", type(of: fact30))
print("30!               :", fact30)
print("(2^127 - 1).isPrime:", ((BigInt(1) << 127) - 1).isPrime == true, "(settled by Lucas-Lehmer)")
print("10^20.nextPrime   :", BigInt(10).power(20).nextPrime)

// MARK: 2. Rational over JSBigInt

banner("Rational<JSBigInt> — BigRat's machinery, JavaScriptCore's digits")
let third = BigInt(1).over(BigInt(3))
print("type(of: third)   :", type(of: third))
print("1/3 + 1/6         :", third + BigInt(1).over(BigInt(6)))
// the harmonic number H_30, exact
let h30 = (1...30).map { BigInt(1).over(BigInt($0)) }.reduce(JSRat(0), +)
print("H_30              :", h30)
print("H_30 as Double    :", h30.toDouble())

// MARK: 3. BigRat still works

banner("BigRat still works (BigNum's own BigInt underneath)")
let tenth = BigRat(0.1)
print("BigRat(0.1)       :", tenth, "— the Double's exact binary value")
print("0.1 + 0.2 == 0.3  :", BigRat(0.1) + BigRat(0.2) == BigRat(0.3))
print("1/10 + 1/5 == 3/10:",
      BNBigInt(1).over(BNBigInt(10)) + BNBigInt(1).over(BNBigInt(5)) == BNBigInt(3).over(BNBigInt(10)))

// MARK: 4. BigFloat still works

banner("BigFloat still works")
print("sqrt(2), 192 bits :", BigFloat.sqrt(BigFloat(2), precision: 192))
print("pi, 192 bits      :", BigFloat.PI(precision: 192))
print("exp(1), 192 bits  :", BigFloat.exp(BigFloat(1), precision: 192))

// MARK: 5. And they interoperate

banner("Interop: JSBigInt <-> BigNum, via BinaryInteger")
let bnFact = BNBigInt(fact30)          // JSBigInt -> BigNum's BigInt
let jsBack = BigInt(bnFact)            // and back
print("30! round trip    :", jsBack == fact30, "(\(type(of: fact30)) -> \(type(of: bnFact)) -> \(type(of: jsBack)))")
let jsRat = BigInt(355).over(BigInt(113))
let bnRat = BNBigInt(jsRat.num).over(BNBigInt(jsRat.den))
print("355/113 as JSRat  :", jsRat, "-> as BigRat:", bnRat)
print("as BigFloat       :", BigFloat(bnRat.toDouble()))
print("vs pi             :", BigFloat.PI(precision: 64))
