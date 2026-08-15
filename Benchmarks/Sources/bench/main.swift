import Foundation
import JSCBigInt
// AttaBigInt (attaswift/BigInt) and DanBigInt (dankogai/swift-bignum) come from
// the shim files; their modules both name the type `BigInt`, so each is
// imported in its own file and re-exported under an unambiguous alias.

// MARK: - Harness

var sink = 0
@inline(never) func blackhole<T>(_ x: T) { sink &+= 1 }

func time(_ body: () -> Void) -> Double {
    let t0 = DispatchTime.now().uptimeNanoseconds
    body()
    return Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e9
}

func bestOf(_ n: Int, _ body: () -> Void) -> Double {
    (0..<n).map { _ in time(body) }.min()!
}

func fmt(_ seconds: Double) -> String {
    seconds < 1 ? String(format: "%.2f ms", seconds * 1e3)
                : String(format: "%.2f s", seconds)
}

struct Case {
    let name: String
    let runs: Int
    let jsc: () -> Void
    let atta: () -> Void
    let dan: () -> Void
}

// MARK: - Shared inputs (identical digits on all sides)

let digits10k = String(repeating: "9876543210", count: 1_000) // 10,000 decimal digits

let jA = JSBigInt(digits10k)!
let jB = jA + 1
let jBig = jA * jA // ~20,000 digits
let aA = AttaBigInt(digits10k)!
let aB = aA + 1
let aBig = aA * aA
let dA = DanBigInt(digits10k)!
let dB = dA + 1
let dBig = dA * dA

let jPow = JSBigInt(2).power(100_000) // 30,103 digits
let aPow = AttaBigInt(2).power(100_000)
let dPow = DanBigInt(2).power(100_000)

// RSA-sized modexp operands: ~2060 bits each
let digits620 = String(repeating: "9876543210", count: 62)
let jMod = JSBigInt(digits620)! + 1 // odd
let jBase = jMod - 12346
let jExp = jMod >> 1
let aMod = AttaBigInt(digits620)! + 1
let aBase = aMod - 12346
let aExp = aMod >> 1
let dMod = DanBigInt(digits620)! + 1
let dBase = dMod - 12346
let dExp = dMod >> 1

// MARK: - Cases

let cases: [Case] = [
    Case(name: "sum 1...100_000 (100k small ops)", runs: 3,
        jsc:  { var s: JSBigInt = 0; for i in 1...100_000 { s += JSBigInt(i) }; blackhole(s) },
        atta: { var s: AttaBigInt = 0; for i in 1...100_000 { s += AttaBigInt(i) }; blackhole(s) },
        dan:  { var s: DanBigInt = 0; for i in 1...100_000 { s += DanBigInt(i) }; blackhole(s) }),
    Case(name: "fib(10_000) (2,090 digits)", runs: 3,
        jsc:  { var (a, b): (JSBigInt, JSBigInt) = (0, 1); for _ in 0..<10_000 { (a, b) = (b, a + b) }; blackhole(a) },
        atta: { var (a, b): (AttaBigInt, AttaBigInt) = (0, 1); for _ in 0..<10_000 { (a, b) = (b, a + b) }; blackhole(a) },
        dan:  { var (a, b): (DanBigInt, DanBigInt) = (0, 1); for _ in 0..<10_000 { (a, b) = (b, a + b) }; blackhole(a) }),
    Case(name: "factorial(1_000) (2,568 digits)", runs: 3,
        jsc:  { blackhole((1...1_000).map { JSBigInt($0) }.reduce(1, *)) },
        atta: { blackhole((1...1_000).map { AttaBigInt($0) }.reduce(1, *)) },
        dan:  { blackhole((1...1_000).map { DanBigInt($0) }.reduce(1, *)) }),
    Case(name: "2.power(100_000) (30,103 digits)", runs: 3,
        jsc:  { blackhole(JSBigInt(2).power(100_000)) },
        atta: { blackhole(AttaBigInt(2).power(100_000)) },
        dan:  { blackhole(DanBigInt(2).power(100_000)) }),
    Case(name: "10k-digit × 10k-digit, 100 times", runs: 3,
        jsc:  { for _ in 0..<100 { blackhole(jA * jB) } },
        atta: { for _ in 0..<100 { blackhole(aA * aB) } },
        dan:  { for _ in 0..<100 { blackhole(dA * dB) } }),
    Case(name: "20k-digit ÷ 10k-digit, 100 times", runs: 3,
        jsc:  { for _ in 0..<100 { blackhole(jBig / jB) } },
        atta: { for _ in 0..<100 { blackhole(aBig / aB) } },
        dan:  { for _ in 0..<100 { blackhole(dBig / dB) } }),
    Case(name: "2060-bit modPow (power(_:mod:))", runs: 3,
        jsc:  { blackhole(jBase.power(jExp, mod: jMod)) },
        atta: { blackhole(aBase.power(aExp, modulus: aMod)) },
        dan:  { blackhole(dBase.power(dExp, mod: dMod)) }),
    Case(name: "toString(2^100_000), decimal", runs: 3,
        jsc:  { blackhole(jPow.description.count) },
        atta: { blackhole(aPow.description.count) },
        dan:  { blackhole(dPow.description.count) }),
    Case(name: "parse 10,000 decimal digits, 100 times", runs: 3,
        jsc:  { for _ in 0..<100 { blackhole(JSBigInt(digits10k)!) } },
        atta: { for _ in 0..<100 { blackhole(AttaBigInt(digits10k)!) } },
        dan:  { for _ in 0..<100 { blackhole(DanBigInt(digits10k)!) } }),
]

// MARK: - Run, emit a Markdown table

// sanity: all libraries agree before we race them
precondition(jBig.description == aBig.description, "libraries disagree!")
precondition(jBig.description == dBig.description, "libraries disagree!")
precondition(jPow.description == aPow.description, "libraries disagree!")
precondition(jPow.description == dPow.description, "libraries disagree!")
let (jM, aM, dM) = (JSBigInt(123).power(jExp, mod: jMod),
                    AttaBigInt(123).power(aExp, modulus: aMod),
                    DanBigInt(123).power(dExp, mod: dMod))
precondition(jM.description == aM.description, "libraries disagree on modPow!")
precondition(jM.description == dM.description, "libraries disagree on modPow!")

print("| Benchmark | JSCBigInt | attaswift/BigInt | swift-bignum |")
print("|:--|--:|--:|--:|")
for c in cases {
    let times = [bestOf(c.runs, c.jsc), bestOf(c.runs, c.atta), bestOf(c.runs, c.dan)]
    let best = times.min()!
    let cells = times.map { t in
        t == best ? "**\(fmt(t))**" : "\(fmt(t)) (\(String(format: "%.1f", t / best))×)"
    }
    print("| \(c.name) | \(cells.joined(separator: " | ")) |")
}
