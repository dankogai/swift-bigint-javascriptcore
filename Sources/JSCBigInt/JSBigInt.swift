#if canImport(JavaScriptCore)
import JavaScriptCore

/// An arbitrary-precision signed integer backed by JavaScriptCore's native `BigInt`.
///
/// Every value wraps a `JSValue` holding a JavaScript `BigInt`; all arithmetic is
/// delegated to a shared `JSContext` with pre-compiled helper functions.
/// Conforms to `SignedInteger`, so it can be used wherever a `BinaryInteger` is expected.
public struct JSBigInt {
    /// The underlying JavaScript `BigInt` value.
    internal let object: JSValue

    internal init(object: JSValue) {
        self.object = object
    }
}

// MARK: - JavaScriptCore engine

extension JSBigInt {
    internal enum Engine {
        static let context = JSContext()!

        /// One JS function per primitive operation, compiled once.
        static let fns: [String: JSValue] = {
            let source = """
            (() => {
                // plain modular exponentiation on non-negative operands, m > 0
                const mpow = (b, e, m) => {
                    let r = 1n % m, x = b % m, ee = e;
                    while (ee > 0n) {
                        if (ee & 1n) r = (r * x) % m;
                        x = (x * x) % m;
                        ee >>= 1n;
                    }
                    return r;
                };
                // one Miller-Rabin round: true when `a` fails to witness `n` composite
                const mrtest = (n, a) => {
                    if (n < 2n) return false;
                    if ((n & 1n) === 0n) return n === 2n;
                    let base = a % n;
                    if (base < 0n) base += n;
                    if (base === 0n) return true;
                    let d = n - 1n, s = 0n;
                    while ((d & 1n) === 0n) { d >>= 1n; s++; }
                    let x = mpow(base, d, n);
                    if (x === 1n || x === n - 1n) return true;
                    for (let i = 1n; i < s; i++) {
                        x = (x * x) % n;
                        if (x === n - 1n) return true;
                    }
                    return false;
                };
                // A014233: below entry i, passing prime bases 0...i proves primality
                const MR_BASES = [2n, 3n, 5n, 7n, 11n, 13n, 17n, 19n, 23n, 29n, 31n, 37n, 41n];
                const MR_TABLE = [
                    2047n, 1373653n, 25326001n, 3215031751n, 2152302898747n,
                    3474749660383n, 341550071728321n, 341550071728321n,
                    3825123056546413051n, 3825123056546413051n, 3825123056546413051n,
                    318665857834031151167461n, 3317044064679887385961981n,
                ];
                const EXTRA_BASES = [43n, 47n, 53n, 59n, 61n, 67n, 71n, 73n, 79n, 83n, 89n, 97n];
                // 0: composite, 1: prime (proven), 2: probably prime (unproven)
                const isprime = (n) => {
                    if (n < 2n) return 0;
                    for (const p of MR_BASES.concat(EXTRA_BASES)) {
                        if (n % p === 0n) return n === p ? 1 : 0;
                    }
                    for (let i = 0; i < MR_BASES.length; i++) {
                        if (!mrtest(n, MR_BASES[i])) return 0;
                        if (n < MR_TABLE[i]) return 1;
                    }
                    for (const a of EXTRA_BASES) {
                        if (!mrtest(n, a)) return 0;
                    }
                    return 2;
                };
                return {
                parse: (s, r) => {
                    try {
                        s = s.trim();
                        let sign = 1n, i = 0;
                        if (s[0] === '+' || s[0] === '-') {
                            if (s[0] === '-') sign = -1n;
                            i = 1;
                        }
                        s = s.slice(i);
                        if (s.length === 0) return null;
                        if (r === 10) {
                            if (!/^[0-9]+$/.test(s)) return null;
                            return sign * BigInt(s);
                        }
                        if (r === 16 && /^[0-9a-fA-F]+$/.test(s)) return sign * BigInt("0x" + s);
                        if (r ===  8 && /^[0-7]+$/.test(s))       return sign * BigInt("0o" + s);
                        if (r ===  2 && /^[01]+$/.test(s))        return sign * BigInt("0b" + s);
                        const R = BigInt(r);
                        let acc = 0n;
                        for (let j = 0; j < s.length; j++) {
                            const c = s.charCodeAt(j);
                            let d;
                            if      (48 <= c && c <=  57) d = c - 48;  // 0-9
                            else if (97 <= c && c <= 122) d = c - 87;  // a-z
                            else if (65 <= c && c <=  90) d = c - 55;  // A-Z
                            else return null;
                            if (d >= r) return null;
                            acc = acc * R + BigInt(d);
                        }
                        return sign * acc;
                    } catch (e) {
                        return null;
                    }
                },
                str: (a, r) => a.toString(r),
                fromWords: (ws) => {
                    let x = 0n;
                    for (let i = ws.length - 1; i >= 0; i--) x = (x << 64n) | BigInt("0x" + ws[i]);
                    return BigInt.asIntN(64 * ws.length, x);
                },
                words: (a) => {
                    const out = [];
                    let x = a;
                    for (;;) {
                        const w = BigInt.asUintN(64, x);
                        x >>= 64n;
                        out.push(w.toString(16));
                        const negBit = (w & 0x8000000000000000n) !== 0n;
                        if ((x === 0n && !negBit) || (x === -1n && negBit)) break;
                    }
                    return out;
                },
                bitWidth: (a) => {
                    const nz = (v) => v === 0n ? 0 : v.toString(2).length;
                    return a >= 0n ? nz(a) + 1 : nz(~a) + 1;
                },
                tzbc: (a) => {
                    if (a === 0n) return 1; // == bitWidth of zero
                    let n = 0, x = a;
                    while ((x & 1n) === 0n) { x >>= 1n; n++; }
                    return n;
                },
                add: (a, b) => a + b,
                sub: (a, b) => a - b,
                mul: (a, b) => a * b,
                div: (a, b) => a / b,
                mod: (a, b) => a % b,
                neg: (a) => -a,
                abs: (a) => a < 0n ? -a : a,
                and: (a, b) => a & b,
                or:  (a, b) => a | b,
                xor: (a, b) => a ^ b,
                not: (a) => ~a,
                shl: (a, b) => a << b,
                shr: (a, b) => a >> b,
                pow: (a, b) => a ** b,
                modpow: (b, e, m) => {
                    const am = m < 0n ? -m : m;
                    let base = b % am;
                    if (base < 0n) base += am;
                    let exp = e;
                    if (exp < 0n) {
                        // extended Euclid: base := base^-1 (mod am), or null if not coprime
                        let [r0, r1] = [base, am];
                        let [s0, s1] = [1n, 0n];
                        while (r1 !== 0n) {
                            const q = r0 / r1;
                            [r0, r1] = [r1, r0 - q * r1];
                            [s0, s1] = [s1, s0 - q * s1];
                        }
                        if (r0 !== 1n) return null;
                        base = s0 % am;
                        if (base < 0n) base += am;
                        exp = -exp;
                    }
                    let result = mpow(base, exp, am);
                    if (m < 0n && result !== 0n) result -= am;
                    return result;
                },
                mrtest: mrtest,
                isprime: isprime,
                nextprime: (n) => {
                    if (n < 2n) return 2n;
                    let u = n + ((n & 1n) === 0n ? 1n : 2n);
                    while (isprime(u) === 0) u += 2n;
                    return u;
                },
                prevprime: (n) => {
                    if (n <= 2n) return null;
                    if (n === 3n) return 2n;
                    let u = n - ((n & 1n) === 0n ? 1n : 2n);
                    while (isprime(u) === 0) u -= 2n;
                    return u;
                },
                gcd: (a, b) => {
                    let x = a < 0n ? -a : a;
                    let y = b < 0n ? -b : b;
                    while (y !== 0n) [x, y] = [y, x % y];
                    return x;
                },
                isqrt: (a) => {
                    if (a < 0n) return null;
                    if (a < 2n) return a;
                    // Newton's method; initial guess 2^(ceil(bits/2)) >= sqrt(a),
                    // so x decreases monotonically to floor(sqrt(a))
                    const bits = BigInt(a.toString(2).length);
                    let x = 1n << ((bits >> 1n) + 1n);
                    for (;;) {
                        const y = (x + a / x) >> 1n;
                        if (y >= x) return x;
                        x = y;
                    }
                },
                eq:  (a, b) => a === b,
                lt:  (a, b) => a < b,
                };
            })()
            """
            let ops = context.evaluateScript(source)!
            var fns = [String: JSValue]()
            for name in ["parse", "str", "fromWords", "words", "bitWidth", "tzbc",
                         "add", "sub", "mul", "div", "mod", "neg", "abs",
                         "and", "or", "xor", "not", "shl", "shr", "pow", "modpow",
                         "gcd", "isqrt", "mrtest", "isprime", "nextprime", "prevprime",
                         "eq", "lt"] {
                fns[name] = ops.objectForKeyedSubscript(name)!
            }
            return fns
        }()
    }

    /// Invokes a pre-compiled JS helper, trapping on JS exceptions
    /// (e.g. `RangeError: Division by zero`) the way Swift integers do.
    internal static func jsop(_ name: String, _ args: [Any]) -> JSValue {
        let result = Engine.fns[name]!.call(withArguments: args)
        if let exception = Engine.context.exception {
            Engine.context.exception = nil
            preconditionFailure("JSBigInt: \(exception)")
        }
        return result!
    }

    internal static func binop(_ name: String, _ lhs: Self, _ rhs: Self) -> Self {
        Self(object: jsop(name, [lhs.object, rhs.object]))
    }
}

// MARK: - Initializers

extension JSBigInt {
    /// Creates a value from its textual representation in the given radix (2...36).
    /// Accepts an optional leading `+` or `-`. Returns `nil` on invalid input.
    public init?(_ description: String, radix: Int) {
        precondition(2 <= radix && radix <= 36, "radix must be in 2...36")
        let value = Self.jsop("parse", [description, radix])
        guard value.isNull == false, value.isUndefined == false else { return nil }
        self.init(object: value)
    }

    public init<T: BinaryInteger>(_ source: T) {
        // BinaryInteger's description is always a decimal string.
        self.init(object: Self.jsop("parse", [String(source), 10]))
    }

    public init?<T: BinaryInteger>(exactly source: T) {
        self.init(source) // arbitrary precision: always exact
    }

    public init<T: BinaryInteger>(clamping source: T) {
        self.init(source)
    }

    public init<T: BinaryInteger>(truncatingIfNeeded source: T) {
        self.init(source)
    }

    public init?<T: BinaryFloatingPoint>(exactly source: T) {
        guard source.isFinite, source.rounded(.towardZero) == source else { return nil }
        self.init(integral: source)
    }

    public init<T: BinaryFloatingPoint>(_ source: T) {
        precondition(source.isFinite, "cannot convert \(source) to JSBigInt")
        self.init(integral: source.rounded(.towardZero))
    }

    /// `source` must be finite and integral.
    private init<T: BinaryFloatingPoint>(integral source: T) {
        if source == 0 {
            self.init(object: Self.jsop("parse", ["0", 10]))
            return
        }
        // A nonzero integral value is normal, so the significand has an implicit
        // leading 1 bit: value = ±(pattern | 1 << significandBitCount) × 2^(exponent - significandBitCount)
        let mantissa = JSBigInt(source.significandBitPattern) | (JSBigInt(1) << T.significandBitCount)
        let shift = Int(source.exponent) - T.significandBitCount
        let magnitude = shift >= 0 ? mantissa << shift : mantissa >> (-shift)
        self = source < 0 ? -magnitude : magnitude
    }
}

// MARK: - String conversions

extension JSBigInt: CustomStringConvertible, LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(description, radix: 10)
    }

    public var description: String {
        toString()
    }

    /// The textual representation in the given radix (2...36), lowercase.
    public func toString(radix: Int = 10) -> String {
        precondition(2 <= radix && radix <= 36, "radix must be in 2...36")
        return Self.jsop("str", [object, radix]).toString()!
    }
}

// MARK: - Equatable, Comparable, Hashable

extension JSBigInt: Comparable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        jsop("eq", [lhs.object, rhs.object]).toBool()
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        jsop("lt", [lhs.object, rhs.object]).toBool()
    }
}

extension JSBigInt: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(toString(radix: 16))
    }
}

// MARK: - Integer literals

extension JSBigInt: ExpressibleByIntegerLiteral {
    /// `StaticBigInt` makes literals of any size work: `let x: JSBigInt = 10 ** 40` digits long.
    public init(integerLiteral value: StaticBigInt) {
        let wordCount = Swift.max(1, (value.bitWidth + 63) / 64)
        let hexWords = (0 ..< wordCount).map { String(value[$0], radix: 16) }
        self.init(object: Self.jsop("fromWords", [hexWords]))
    }
}

// MARK: - SignedInteger

extension JSBigInt: SignedInteger {
    public typealias Magnitude = JSBigInt
    public typealias Words = [UInt]
    public typealias Stride = Int

    public static var isSigned: Bool { true }

    public var magnitude: JSBigInt {
        JSBigInt(object: Self.jsop("abs", [object]))
    }

    /// Two's-complement words, least significant first, minimally sign-extended.
    public var words: [UInt] {
        let hexWords = Self.jsop("words", [object]).toArray() as! [String]
        return hexWords.map { UInt(UInt64($0, radix: 16)!) }
    }

    /// The bit width of the minimal two's-complement representation, including the sign bit.
    public var bitWidth: Int {
        Int(Self.jsop("bitWidth", [object]).toDouble())
    }

    public var trailingZeroBitCount: Int {
        Int(Self.jsop("tzbc", [object]).toDouble())
    }

    // Arithmetic
    public static func + (lhs: Self, rhs: Self) -> Self { binop("add", lhs, rhs) }
    public static func - (lhs: Self, rhs: Self) -> Self { binop("sub", lhs, rhs) }
    public static func * (lhs: Self, rhs: Self) -> Self { binop("mul", lhs, rhs) }
    /// Truncating division, like Swift's `/` (JS `BigInt` division also truncates toward zero).
    public static func / (lhs: Self, rhs: Self) -> Self { binop("div", lhs, rhs) }
    /// Remainder with the sign of the dividend, like Swift's `%`.
    public static func % (lhs: Self, rhs: Self) -> Self { binop("mod", lhs, rhs) }

    public static func += (lhs: inout Self, rhs: Self) { lhs = lhs + rhs }
    public static func -= (lhs: inout Self, rhs: Self) { lhs = lhs - rhs }
    public static func *= (lhs: inout Self, rhs: Self) { lhs = lhs * rhs }
    public static func /= (lhs: inout Self, rhs: Self) { lhs = lhs / rhs }
    public static func %= (lhs: inout Self, rhs: Self) { lhs = lhs % rhs }

    public mutating func negate() {
        self = Self(object: Self.jsop("neg", [object]))
    }

    // Bitwise
    public static func & (lhs: Self, rhs: Self) -> Self { binop("and", lhs, rhs) }
    public static func | (lhs: Self, rhs: Self) -> Self { binop("or", lhs, rhs) }
    public static func ^ (lhs: Self, rhs: Self) -> Self { binop("xor", lhs, rhs) }

    public static func &= (lhs: inout Self, rhs: Self) { lhs = lhs & rhs }
    public static func |= (lhs: inout Self, rhs: Self) { lhs = lhs | rhs }
    public static func ^= (lhs: inout Self, rhs: Self) { lhs = lhs ^ rhs }

    public static prefix func ~ (x: Self) -> Self {
        Self(object: jsop("not", [x.object]))
    }

    // Shifts: JS BigInt shifts are arithmetic and accept negative counts natively,
    // which matches BinaryInteger's "smart shift" semantics.
    public static func << <RHS: BinaryInteger>(lhs: Self, rhs: RHS) -> Self {
        binop("shl", lhs, Self(rhs))
    }

    public static func >> <RHS: BinaryInteger>(lhs: Self, rhs: RHS) -> Self {
        binop("shr", lhs, Self(rhs))
    }

    public static func <<= <RHS: BinaryInteger>(lhs: inout Self, rhs: RHS) { lhs = lhs << rhs }
    public static func >>= <RHS: BinaryInteger>(lhs: inout Self, rhs: RHS) { lhs = lhs >> rhs }

    // Strideable (Int strides; conversion traps on overflow like Int does)
    public func distance(to other: Self) -> Int { Int(other - self) }
    public func advanced(by n: Int) -> Self { self + Self(n) }
}

// MARK: - Exponentiation

extension JSBigInt {
    /// `self` raised to `exponent` (which must be non-negative), via JS `**`.
    public func power(_ exponent: some BinaryInteger) -> Self {
        precondition(exponent >= 0, "exponent must be non-negative")
        return Self.binop("pow", self, Self(exponent))
    }

    /// Modular exponentiation: `self` raised to `exponent`, modulo `modulus`,
    /// by square-and-multiply — only the modulus bounds the intermediates, so
    /// huge exponents stay cheap where `power(_:)` could not run at all.
    ///
    /// Semantics match swift-bignum's `power(_:mod:)`:
    /// * The result is the **least residue of matching sign**: in `0..<|m|` for
    ///   a positive modulus (so `JSBigInt(-2).power(3, mod: 5)` is `2`, where
    ///   `JSBigInt(-2).power(3) % 5` is `-3`), and in `(m, 0]` for a negative one.
    /// * A **negative `exponent`** raises the modular inverse of `self`, so
    ///   `x.power(-1, mod: m)` *is* that inverse.  It traps when `self` and
    ///   `modulus` are not coprime, there being no inverse to return.
    /// * A **zero `modulus`** traps.
    public func power(_ exponent: some BinaryInteger, mod modulus: Self) -> Self {
        precondition(modulus != 0, "power(_:mod:) with a modulus of zero")
        let result = Self.jsop("modpow", [object, Self(exponent).object, modulus.object])
        guard result.isNull == false else {
            preconditionFailure("\(self) has no inverse modulo \(modulus)")
        }
        return Self(object: result)
    }
}

// MARK: - GCD and integer square root

extension JSBigInt {
    /// The greatest common divisor of `self` and `other`, by Euclid's algorithm
    /// on the magnitudes — never negative, and zero only when both are zero.
    public func greatestCommonDivisor(with other: Self) -> Self {
        Self.binop("gcd", self, other)
    }

    /// The integer square root: the largest value whose square is at most `self`.
    /// Traps when `self` is negative, like swift-bignum's `squareRoot()`.
    public func squareRoot() -> Self {
        let result = Self.jsop("isqrt", [object])
        guard result.isNull == false else {
            preconditionFailure("square root of a negative JSBigInt")
        }
        return Self(object: result)
    }
}

// MARK: - Primality

extension JSBigInt {
    /// A single Miller-Rabin round: `true` when `base` fails to witness `self`
    /// composite.  A single base proves nothing on its own (2047 = 23 × 89
    /// passes base 2); use `isPrime` or `isProbablePrime` for an actual verdict.
    public func millerRabinTest(base: Self) -> Bool {
        Self.jsop("mrtest", [object, base.object]).toBool()
    }

    /// `true` if `self` passes Miller-Rabin with the first 25 primes as bases.
    ///
    /// Below 3317044064679887385961981 — the last entry of [A014233] — the
    /// first 13 of those bases constitute a *proof*, so no wrong answer is
    /// possible there.  Above it, no composite is known to pass all 25, but
    /// constructions exist against any fixed base set, which is why `isPrime`
    /// withholds its answer past the bound and this one is spelled "probable".
    ///
    /// [A014233]: https://oeis.org/A014233
    public var isProbablePrime: Bool {
        Int32(Self.jsop("isprime", [object]).toInt32()) != 0
    }

    /// Whether `self` is prime, or `nil` when Miller-Rabin cannot settle it.
    ///
    /// Follows swift-bignum's contract: `false` is always a proof (a witness
    /// to compositeness is a proof), `true` is a proof (deterministic below
    /// [A014233]'s last entry, 3317044064679887385961981), and past that bound
    /// a passing value is only *probably* prime, so this returns `nil` rather
    /// than laundering the probability into a fact — `isProbablePrime` is that
    /// opinion.  `nil` is not "no": treat it deliberately, with `== true`,
    /// rather than by reaching for `??`.
    ///
    /// [A014233]: https://oeis.org/A014233
    public var isPrime: Bool? {
        switch Self.jsop("isprime", [object]).toInt32() {
        case 0:  return false
        case 1:  return true
        default: return nil
        }
    }

    /// The first prime greater than `self`; anything below 2 gets 2.
    ///
    /// The walk is on `isProbablePrime`, not `isPrime`: past the deterministic
    /// range `isPrime` is `nil`, and a walk that read that as "composite"
    /// would step over every candidate and never return.  So above the
    /// [A014233] bound this is the next *probable* prime.
    ///
    /// [A014233]: https://oeis.org/A014233
    public var nextPrime: Self {
        Self(object: Self.jsop("nextprime", [object]))
    }

    /// The last prime less than `self`, or `nil` when there is none — which is
    /// what 2 and everything below it gets.  Probable above the A014233 bound,
    /// as `nextPrime` is.
    public var prevPrime: Self? {
        let result = Self.jsop("prevprime", [object])
        return result.isNull ? nil : Self(object: result)
    }
}

// MARK: - Codable

extension JSBigInt: Codable {
    /// Encoded as a decimal string, since most JSON decoders cannot handle huge numbers.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = JSBigInt(string) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "invalid JSBigInt string: \(string)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

// MARK: - Sendable

// Values are immutable once created, and JavaScriptCore serializes all API access
// through the JSVirtualMachine lock, so cross-thread use is safe.
extension JSBigInt: @unchecked Sendable {}

#endif // canImport(JavaScriptCore)
