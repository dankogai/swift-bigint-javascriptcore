//
//  JSCBigNum -- the conformance glue that lets JSBigInt ride swift-bignum's
//  generic machinery.  Two retroactive conformances and three typealiases;
//  everything else is what the two libraries already were.
//
import BigNum
import JSCBigInt

// `Rational` is generic over `RationalElement`, so JSBigInt can be its
// element.  JSBigInt's own greatestCommonDivisor(with:) and squareRoot() are
// the witnesses -- both requirements since swift-bignum#31 -- so reduction
// runs in JavaScriptCore too.
extension JSBigInt: @retroactive RationalElement {}

// BigFloatOf<IntType> takes any BigIntegerType & RationalElement.  JSBigInt
// satisfies BigIntegerType save for spelling out `isZero`; string parsing and
// toString(radix:uppercase:) come from the protocol's own defaults.
extension JSBigInt: @retroactive BigIntegerType {
    public var isZero: Bool { self == 0 }
}

/// BigRat's machinery, JavaScriptCore's digits.
public typealias JSRat = Rational<JSBigInt>

/// BigFloat's machinery, JavaScriptCore's mantissa.
public typealias JSFloat = BigFloatOf<JSBigInt>

/// BigNum's own `BigInt`, still reachable -- not as `BigNum.BigInt` (the
/// `BigNum` *protocol* shadows the module name in qualified lookup), but
/// through an associated type that never stopped pointing at it.
public typealias BNBigInt = BigFloat.Significand
