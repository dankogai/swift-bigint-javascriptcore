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
