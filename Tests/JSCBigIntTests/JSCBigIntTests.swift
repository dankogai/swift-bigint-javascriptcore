#if canImport(JavaScriptCore)
import Testing
import Foundation
@testable import JSCBigInt

@Suite struct JSBigIntTests {
    @Test func integerLiterals() {
        // StaticBigInt literals: arbitrary size, no strings needed
        let huge: JSBigInt = 123456789012345678901234567890123456789012345678901234567890
        #expect(huge.description == "123456789012345678901234567890123456789012345678901234567890")
        let negHuge: JSBigInt = -0x1_0000_0000_0000_0000 // -(2^64)
        #expect(negHuge == -(JSBigInt(1) << 64))
        #expect((0 as JSBigInt).description == "0")
        #expect((-42 as JSBigInt).description == "-42")
    }

    @Test func stringConversions() {
        let x = JSBigInt("123456789123456789123456789")
        #expect(x != nil)
        #expect(x!.description == "123456789123456789123456789")
        #expect(JSBigInt("deadbeef", radix: 16) == 0xdeadbeef)
        #expect(JSBigInt("-DEADBEEF", radix: 16) == -0xdeadbeef)
        #expect(JSBigInt("777", radix: 8) == 0o777)
        #expect(JSBigInt("101010", radix: 2) == 0b101010)
        #expect(JSBigInt("zz", radix: 36) == 1295) // 35 * 36 + 35
        #expect(JSBigInt("+123") == 123)
        #expect(JSBigInt("") == nil)
        #expect(JSBigInt("12a") == nil)
        #expect(JSBigInt("-") == nil)
        #expect(JSBigInt("z", radix: 35) == nil)

        let big = JSBigInt(1) << 200 - 1
        for radix in [2, 8, 10, 16, 36] {
            #expect(JSBigInt(big.toString(radix: radix), radix: radix) == big)
        }
        #expect((255 as JSBigInt).toString(radix: 16) == "ff")
        #expect((-255 as JSBigInt).toString(radix: 16) == "-ff")
    }

    @Test func arithmetic() {
        let a: JSBigInt = 123456789123456789123456789
        let b: JSBigInt = 987654321987654321987654321
        #expect(a + b == 1111111111111111111111111110)
        #expect(b - a == 864197532864197532864197532)
        #expect(a * b == 121932631356500531591068431581771069347203169112635269)
        #expect((a + b) - b == a)
        #expect(2.0 * Double(a) != 0) // just exercise Double conversion path

        // factorial(100), the classic sanity check
        let fact100 = (1...100).map { JSBigInt($0) }.reduce(1, *)
        #expect(fact100.description ==
            "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000")

        // 2^128
        #expect(JSBigInt(2).power(128).description == "340282366920938463463374607431768211456")
    }

    @Test func divisionSemantics() {
        // Swift semantics: / truncates toward zero, % takes the dividend's sign
        #expect((-7 as JSBigInt) / 2 == -3)
        #expect((-7 as JSBigInt) % 2 == -1)
        #expect((7 as JSBigInt) / -2 == -3)
        #expect((7 as JSBigInt) % -2 == 1)
        let (q, r) = JSBigInt(-7).quotientAndRemainder(dividingBy: 2)
        #expect(q == -3 && r == -1)
        #expect(JSBigInt(12).isMultiple(of: 4))
        #expect(!JSBigInt(12).isMultiple(of: 5))
    }

    @Test func bitwiseAndShifts() {
        let x: JSBigInt = 0b1100
        let y: JSBigInt = 0b1010
        #expect(x & y == 0b1000)
        #expect(x | y == 0b1110)
        #expect(x ^ y == 0b0110)
        #expect(~x == -13)
        #expect(JSBigInt(1) << 100 == JSBigInt("1267650600228229401496703205376"))
        #expect((JSBigInt(1) << 100) >> 100 == 1)
        #expect(JSBigInt(1) << -2 == 0)     // smart shift: negative count reverses direction
        #expect(JSBigInt(16) >> -2 == 64)
        #expect(JSBigInt(-1) >> 1000 == -1) // arithmetic shift
    }

    @Test func comparisons() {
        let values: [JSBigInt] = [3, -5, 0, 12345678901234567890123456789, -12345678901234567890123456789]
        let sorted = values.sorted()
        #expect(sorted == [-12345678901234567890123456789, -5, 0, 3, 12345678901234567890123456789])
        #expect(JSBigInt(5) > 4)
        #expect(JSBigInt(-5) < -4)
        #expect(JSBigInt(5).signum() == 1)
        #expect(JSBigInt(-5).signum() == -1)
        #expect(JSBigInt(0).signum() == 0)
        #expect(abs(JSBigInt(-42)) == 42)
        #expect(JSBigInt(-42).magnitude == 42)
    }

    @Test func integerConversions() {
        #expect(JSBigInt(Int.max).description == "\(Int.max)")
        #expect(JSBigInt(Int.min).description == "\(Int.min)")
        #expect(JSBigInt(UInt64.max).description == "18446744073709551615")
        #expect(Int(JSBigInt(Int.max)) == Int.max)
        #expect(Int(JSBigInt(Int.min)) == Int.min)
        #expect(UInt64(JSBigInt(UInt64.max)) == UInt64.max)
        #expect(Int8(JSBigInt(-128)) == -128)
        #expect(Int(exactly: JSBigInt(1) << 100) == nil)
        #expect(Int(exactly: JSBigInt(42)) == 42)
        #expect(UInt(exactly: JSBigInt(-1)) == nil)
    }

    @Test func floatingPointConversions() {
        #expect(JSBigInt(3.75) == 3)
        #expect(JSBigInt(-3.75) == -3)
        #expect(JSBigInt(exactly: 3.75) == nil)
        #expect(JSBigInt(exactly: 4.0) == 4)
        #expect(JSBigInt(exactly: Double.nan) == nil)
        #expect(JSBigInt(exactly: Double.infinity) == nil)
        // 2^100 is exactly representable as a Double
        let d = Double(sign: .plus, exponent: 100, significand: 1)
        #expect(JSBigInt(exactly: d) == JSBigInt(1) << 100)
        #expect(Double(JSBigInt(1) << 100) == d)
        #expect(Double(JSBigInt(3)) == 3.0)
        #expect(Float(JSBigInt(-12345)) == -12345.0)
    }

    @Test func wordsAndBitWidth() {
        #expect(JSBigInt(0).words == [0])
        #expect(JSBigInt(1).words == [1])
        #expect(JSBigInt(-1).words == [UInt.max])
        #expect(JSBigInt(UInt64.max).words == [UInt.max, 0])
        #expect((JSBigInt(1) << 64).words == [0, 1])
        #expect(JSBigInt(Int.min).words == [UInt(bitPattern: Int.min)])

        #expect(JSBigInt(0).bitWidth == 1)
        #expect(JSBigInt(1).bitWidth == 2)
        #expect(JSBigInt(-1).bitWidth == 1)
        #expect(JSBigInt(-2).bitWidth == 2)
        #expect(JSBigInt(127).bitWidth == 8)
        #expect(JSBigInt(128).bitWidth == 9)
        #expect(JSBigInt(-128).bitWidth == 8)
        #expect((JSBigInt(1) << 100).bitWidth == 102)

        #expect(JSBigInt(0).trailingZeroBitCount == 1) // == bitWidth, per BinaryInteger docs
        #expect(JSBigInt(1).trailingZeroBitCount == 0)
        #expect(JSBigInt(8).trailingZeroBitCount == 3)
        #expect((JSBigInt(1) << 100).trailingZeroBitCount == 100)
        #expect(JSBigInt(-8).trailingZeroBitCount == 3)
    }

    @Test func hashing() {
        let a = JSBigInt("123456789123456789123456789")!
        let b = JSBigInt("123456789123456789123456788")! + 1
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        let set: Set<JSBigInt> = [a, b, 42, 42]
        #expect(set.count == 2)
    }

    @Test func codable() throws {
        let original: [JSBigInt] = [0, -1, 12345678901234567890123456789012345678901234567890]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([JSBigInt].self, from: data)
        #expect(decoded == original)
        #expect(String(data: data, encoding: .utf8)!.contains("\"-1\""))
    }

    @Test func genericAlgorithms() {
        // JSBigInt should work in any BinaryInteger-generic code
        func gcd<T: BinaryInteger>(_ a: T, _ b: T) -> T {
            var (a, b) = (a, b)
            while b != 0 { (a, b) = (b, a % b) }
            return a
        }
        let f90 = (1...90).map { JSBigInt($0) }.reduce(1, *)
        let f92 = (1...92).map { JSBigInt($0) }.reduce(1, *)
        #expect(gcd(f90, f92) == f90)
        #expect(gcd(JSBigInt(48), JSBigInt(18)) == 6)

        // Strideable
        let sum = stride(from: JSBigInt(1), through: 10, by: 1).reduce(0, +)
        #expect(sum == 55)
    }

    @Test func modularExponentiation() {
        #expect(JSBigInt(2).power(10, mod: 1000) == 24)
        #expect(JSBigInt(2).power(0, mod: 1000) == 1)
        #expect(JSBigInt(5).power(0, mod: 1) == 0)   // everything is 0 mod 1
        // least non-negative residue, unlike truncated %
        #expect(JSBigInt(-2).power(3, mod: 5) == 2)
        #expect(JSBigInt(-2).power(3) % 5 == -3)
        // negative modulus: least residue in (m, 0]
        #expect(JSBigInt(2).power(10, mod: -1000) == -976)
        // agreement with plain power where both are computable
        #expect(JSBigInt(7).power(20, mod: 1000003) == JSBigInt(7).power(20) % 1000003)
        // negative exponent is the modular inverse
        #expect(JSBigInt(3).power(-1, mod: 7) == 5)  // 3 * 5 == 15 ≡ 1 (mod 7)
        #expect(JSBigInt(3).power(-2, mod: 7) == 4)  // 5 * 5 == 25 ≡ 4 (mod 7)
        // Fermat's little theorem: a^(p-1) ≡ 1 (mod p) for prime p ∤ a
        let p: JSBigInt = 1000000007
        #expect(JSBigInt(12345).power(p - 1, mod: p) == 1)
        // RSA textbook example: n = 61 * 53, e = 17, d = 2753
        let n: JSBigInt = 3233
        let c = JSBigInt(65).power(17, mod: n)
        #expect(c == 2790)
        #expect(c.power(2753, mod: n) == 65)
        // huge exponent that plain power(_:) could never materialize
        #expect(JSBigInt(2).power(JSBigInt(1) << 512, mod: 1_000_000_007) == 656254629)
    }

    @Test func greatestCommonDivisor() {
        #expect(JSBigInt(48).greatestCommonDivisor(with: 18) == 6)
        #expect(JSBigInt(-48).greatestCommonDivisor(with: 18) == 6)   // never negative
        #expect(JSBigInt(48).greatestCommonDivisor(with: -18) == 6)
        #expect(JSBigInt(0).greatestCommonDivisor(with: 5) == 5)
        #expect(JSBigInt(0).greatestCommonDivisor(with: 0) == 0)      // only zero case
        #expect(JSBigInt(17).greatestCommonDivisor(with: 19) == 1)    // coprime
        let p2_100 = JSBigInt(1) << 100
        #expect(p2_100.greatestCommonDivisor(with: JSBigInt(1) << 60) == JSBigInt(1) << 60)
        let f90 = (1...90).map { JSBigInt($0) }.reduce(1, *)
        let f92 = f90 * 91 * 92
        #expect(f90.greatestCommonDivisor(with: f92) == f90)
    }

    @Test func squareRoot() {
        #expect(JSBigInt(0).squareRoot() == 0)
        #expect(JSBigInt(1).squareRoot() == 1)
        #expect(JSBigInt(2).squareRoot() == 1)
        #expect(JSBigInt(3).squareRoot() == 1)
        #expect(JSBigInt(4).squareRoot() == 2)
        #expect(JSBigInt(15).squareRoot() == 3)
        #expect(JSBigInt(16).squareRoot() == 4)
        #expect(JSBigInt(17).squareRoot() == 4)
        // floor semantics around a huge perfect square
        let n = JSBigInt(10).power(50) + 12345
        #expect((n * n).squareRoot() == n)
        #expect((n * n - 1).squareRoot() == n - 1)
        #expect((n * n + 1).squareRoot() == n)
        // consistency: r^2 <= x < (r+1)^2
        let x = JSBigInt("123456789", radix: 10)!.power(7)
        let r = x.squareRoot()
        #expect(r * r <= x && x < (r + 1) * (r + 1))
    }

    @Test func primality() {
        // small values: proven either way
        #expect(JSBigInt(-7).isPrime == false)
        #expect(JSBigInt(0).isPrime == false)
        #expect(JSBigInt(1).isPrime == false)
        #expect(JSBigInt(2).isPrime == true)
        #expect(JSBigInt(3).isPrime == true)
        #expect(JSBigInt(4).isPrime == false)
        #expect(JSBigInt(97).isPrime == true)
        #expect(JSBigInt(91).isPrime == false)       // 7 × 13
        #expect(JSBigInt(1000003).isPrime == true)
        #expect(JSBigInt(1000001).isPrime == false)  // 101 × 9901
        // Carmichael numbers fool Fermat, not Miller-Rabin
        #expect(JSBigInt(561).isPrime == false)
        #expect(JSBigInt(1105).isPrime == false)
        #expect(JSBigInt(1729).isPrime == false)
        // 2047 = 23 × 89 is a strong pseudoprime to base 2: one round lies,
        // the verdict does not
        #expect(JSBigInt(2047).millerRabinTest(base: 2))
        #expect(JSBigInt(2047).isPrime == false)
        // beyond 2^64 but inside A014233's deterministic range: still a proof
        #expect(JSBigInt("100000000000000000039")!.isPrime == true)
        #expect(JSBigInt("100000000000000000037")!.isPrime == false)
        // beyond the deterministic range: Miller-Rabin has an opinion but no proof
        let m89 = (JSBigInt(1) << 89) - 1   // Mersenne prime 2^89 - 1
        #expect(m89.isProbablePrime)
        #expect(m89.isPrime == nil)
        let m127 = (JSBigInt(1) << 127) - 1 // Mersenne prime 2^127 - 1
        #expect(m127.isProbablePrime)
        #expect(m127.isPrime == nil)
        // a witness is a proof at any size
        #expect((m89 * m127).isPrime == false)
        #expect((m127 * m127).isPrime == false)
    }

    @Test func primeWalking() {
        // nextPrime: anything below 2 gets 2
        #expect(JSBigInt(-5).nextPrime == 2)
        #expect(JSBigInt(0).nextPrime == 2)
        #expect(JSBigInt(1).nextPrime == 2)
        #expect(JSBigInt(2).nextPrime == 3)
        #expect(JSBigInt(3).nextPrime == 5)
        #expect(JSBigInt(7).nextPrime == 11)
        #expect(JSBigInt(89).nextPrime == 97)
        // prevPrime: 2 and below have no answer
        #expect(JSBigInt(-5).prevPrime == nil)
        #expect(JSBigInt(2).prevPrime == nil)
        #expect(JSBigInt(3).prevPrime == 2)
        #expect(JSBigInt(4).prevPrime == 3)
        #expect(JSBigInt(100).prevPrime == 97)
        // around 10^20, straddling 2^64 but inside the deterministic range
        let p20 = JSBigInt(10).power(20)
        #expect(p20.nextPrime == JSBigInt("100000000000000000039"))
        #expect(p20.prevPrime == JSBigInt("99999999999999999989"))
        // walking is exclusive: a prime's neighbors skip the prime itself
        let p = JSBigInt("100000000000000000039")!
        #expect(p.prevPrime == JSBigInt("99999999999999999989"))
        #expect(JSBigInt("99999999999999999989")!.nextPrime == p)
        // past the deterministic range the walk still terminates, on the
        // probable test
        let m89 = (JSBigInt(1) << 89) - 1
        let q = m89.nextPrime
        #expect(q > m89 && q.isProbablePrime && q.isPrime == nil)
        #expect(q.prevPrime == m89)  // 2^89 - 1 is itself prime
    }

    @Test func primeSequence() {
        #expect(Array(JSBigInt.primes.prefix(10)) == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29])
        // endless and lazy: only walks as far as asked
        #expect(JSBigInt.primes.first(where: { $0 > 1000 }) == 1009)
        #expect(JSBigInt.primes.prefix(while: { $0 < 100 }).reduce(0, +) == 1060)
        // independent iterators do not share state
        let a = JSBigInt.primes.makeIterator()
        var b = a, c = a
        #expect(b.next() == 2 && b.next() == 3)
        #expect(c.next() == 2)
    }

    @Test func fibonacci() {
        func fib(_ n: Int) -> JSBigInt {
            var (a, b): (JSBigInt, JSBigInt) = (0, 1)
            for _ in 0..<n { (a, b) = (b, a + b) }
            return a
        }
        #expect(fib(100).description == "354224848179261915075")
        #expect(fib(10) == 55)
    }
}
#endif // canImport(JavaScriptCore)
