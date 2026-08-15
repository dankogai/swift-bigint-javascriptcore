import Foundation
import Testing
import BigNum
import JSCBigInt
import JSCBigNum

@Suite struct JSRatTests {
    @Test func arithmetic() {
        let third = JSBigInt(1).over(JSBigInt(3))
        #expect(third + JSBigInt(1).over(JSBigInt(6)) == JSBigInt(1).over(JSBigInt(2)))
        #expect(third * 3 == 1)
        #expect(third - third == 0)
    }

    @Test func reduction() {
        // reduction runs through JSBigInt's own gcd (a RationalElement
        // requirement since swift-bignum#31)
        let q = JSBigInt(6).over(JSBigInt(8))
        #expect(q.num == 3 && q.den == 4)
        let h10 = (1...10).map { JSBigInt(1).over(JSBigInt($0)) }.reduce(JSRat(0), +)
        #expect(h10.num == 7381 && h10.den == 2520)
    }

    @Test func comparisonsAndMixed() {
        #expect(JSBigInt(1).over(JSBigInt(3)) < JSBigInt(1).over(JSBigInt(2)))
        #expect(JSBigInt(-1).over(JSBigInt(3)) < JSRat(0))
        let (i, f) = JSBigInt(7).over(JSBigInt(3)).toMixed()
        #expect(i == 2 && f == JSBigInt(1).over(JSBigInt(3)))
        #expect(JSBigInt(22).over(JSBigInt(7)).toDouble() == 22.0 / 7.0)
    }

    @Test func squareRoot() {
        let two = JSBigInt(2).over(JSBigInt(1))
        let root = two.squareRoot(precision: 128)
        // r^2 <= 2 < (r + ulp)^2, and it must agree with BigRat's own digits
        #expect(root * root <= two)
        let reference = BNBigInt(2).over(BNBigInt(1)).squareRoot(precision: 128)
        #expect(root.num.description == reference.num.description)
        #expect(root.den.description == reference.den.description)
    }
}

@Suite struct JSFloatTests {
    @Test func mantissaIsJSBigInt() {
        #expect(type(of: JSFloat(2).mantissa) == JSBigInt.self)
    }

    @Test func agreesWithBigFloat() {
        // the point of the whole exercise: same machinery, different digits,
        // digit-for-digit identical output
        for px in [64, 128, 192] {
            #expect(JSFloat.PI(precision: px).description
                 == BigFloat.PI(precision: px).description)
            #expect(JSFloat.sqrt(JSFloat(2), precision: px).description
                 == BigFloat.sqrt(BigFloat(2), precision: px).description)
            #expect(JSFloat.exp(JSFloat(1), precision: px).description
                 == BigFloat.exp(BigFloat(1), precision: px).description)
            #expect(JSFloat.log(JSFloat(10), precision: px).description
                 == BigFloat.log(BigFloat(10), precision: px).description)
        }
    }

    @Test func knownDigits() {
        #expect(JSFloat.PI(precision: 128).description.hasPrefix("3.14159265358979323846"))
        #expect(JSFloat.sqrt(JSFloat(2), precision: 128).description.hasPrefix("1.41421356237309504880"))
        #expect(JSFloat.exp(JSFloat(1), precision: 128).description.hasPrefix("2.71828182845904523536"))
    }

    @Test func arithmetic() {
        #expect(JSFloat(2) + JSFloat(3) == 5)
        #expect(JSFloat(2) * JSFloat(3) == 6)
        #expect((JSFloat(1) / JSFloat(4)).description == "0.25")
        #expect(JSFloat(2).power(JSBigInt(10)) == 1024)
        #expect((JSFloat(0.5) + JSFloat(0.25)).description == "0.75")
    }

    @Test func zeroIsWellBehaved() {
        // regression: JSBigInt(0).trailingZeroBitCount == 1 (the stdlib's own
        // convention) once smeared the scale, making a literal 0 a denormal
        // whose negation read as -infinity -- and 2 < 0 came out true
        let zero: JSFloat = 0
        #expect(zero.isZero)
        #expect(zero.scale == 0 && zero.mantissa == 0)
        #expect(!(-zero).isInfinite)
        #expect((-zero).isZero)
        #expect((JSFloat(2) - JSFloat(2)).isZero)
        #expect(!(JSFloat(2) < 0))
        #expect(JSFloat(0) < JSFloat(2))
        #expect(!JSFloat(2).squareRoot(precision: 64).isNaN)
    }

    @Test func specialValues() {
        #expect(JSFloat.nan.isNaN)
        #expect(JSFloat.infinity.isInfinite)
        #expect((-JSFloat.infinity).sign == .minus)
        #expect((JSFloat(1) / JSFloat(0)).isInfinite)
        #expect(JSFloat(-1).squareRoot(precision: 64).isNaN)
        #expect(JSFloat.negativeZero.isZero)
        #expect(JSFloat.negativeZero == JSFloat.zero)
    }

    @Test func conversions() {
        #expect(Double(JSFloat(0.375)) == 0.375)
        #expect(JSFloat(3.75).toDouble() == 3.75)
        // exact BigRat bridge in both directions
        let x = JSFloat(3) / JSFloat(4)
        #expect(x.toBigRat() == BigRat(3, 4))
        #expect(JSFloat(BigRat(3, 4)) == x)
        // and the same-element Rational bridge
        let r = x.toRational()
        #expect(r.num == 3 && r.den == 4)
        // BinaryInteger both ways
        #expect(JSFloat(JSBigInt(1) << 100).exponent == 100)
        #expect(BNBigInt(12345) == BNBigInt(JSBigInt(12345)))
    }

    @Test func stringParsing() {
        // the generic parser: IntType(String, radix:) underneath
        #expect(JSFloat("3.5") == 3.5)
        #expect(JSFloat("-0.25") == -0.25)
        #expect(JSFloat("1.5e3") == 1500)
        #expect(JSFloat("0x1.8p1") == 3)
        #expect(JSFloat("0b101") == 5)
        #expect(JSFloat("nonsense") == nil)
        #expect(JSFloat("1e") == nil)
        #expect(JSFloat("") == nil)
    }

    @Test func precisionKnob() {
        // the static knobs moved to per-specialization storage; setting
        // JSFloat's must not disturb BigFloat's
        let saved = JSFloat.precision
        defer { JSFloat.precision = saved }
        JSFloat.precision = 64
        #expect(JSFloat.precision == 64)
        #expect(BigFloat.precision == 128)
    }

    @Test func codable() throws {
        let original = JSFloat.PI(precision: 128)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSFloat.self, from: data)
        #expect(decoded == original)
    }
}
