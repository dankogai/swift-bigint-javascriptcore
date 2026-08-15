import Foundation
import BigInt     // attaswift/BigInt
import JSCBigInt  // this package

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
    let att: () -> Void
}

// MARK: - Shared inputs (identical digits on both sides)

let digits10k = String(repeating: "9876543210", count: 1_000) // 10,000 decimal digits

let jA = JSBigInt(digits10k)!
let jB = jA + 1
let jBig = jA * jA // ~20,000 digits
let aA = BigInt(digits10k)!
let aB = aA + 1
let aBig = aA * aA

let jPow = JSBigInt(2).power(100_000) // 30,103 digits
let aPow = BigInt(2).power(100_000)

// MARK: - Cases

let cases: [Case] = [
    Case(name: "sum 1...100_000 (100k small ops)", runs: 3,
        jsc: { var s: JSBigInt = 0; for i in 1...100_000 { s += JSBigInt(i) }; blackhole(s) },
        att: { var s: BigInt = 0; for i in 1...100_000 { s += BigInt(i) }; blackhole(s) }),
    Case(name: "fib(10_000) (2,090 digits)", runs: 3,
        jsc: { var (a, b): (JSBigInt, JSBigInt) = (0, 1); for _ in 0..<10_000 { (a, b) = (b, a + b) }; blackhole(a) },
        att: { var (a, b): (BigInt, BigInt) = (0, 1); for _ in 0..<10_000 { (a, b) = (b, a + b) }; blackhole(a) }),
    Case(name: "factorial(1_000) (2,568 digits)", runs: 3,
        jsc: { blackhole((1...1_000).map { JSBigInt($0) }.reduce(1, *)) },
        att: { blackhole((1...1_000).map { BigInt($0) }.reduce(1, *)) }),
    Case(name: "2.power(100_000) (30,103 digits)", runs: 3,
        jsc: { blackhole(JSBigInt(2).power(100_000)) },
        att: { blackhole(BigInt(2).power(100_000)) }),
    Case(name: "10k-digit × 10k-digit, 100 times", runs: 3,
        jsc: { for _ in 0..<100 { blackhole(jA * jB) } },
        att: { for _ in 0..<100 { blackhole(aA * aB) } }),
    Case(name: "20k-digit ÷ 10k-digit, 100 times", runs: 3,
        jsc: { for _ in 0..<100 { blackhole(jBig / jB) } },
        att: { for _ in 0..<100 { blackhole(aBig / aB) } }),
    Case(name: "toString(2^100_000), decimal", runs: 3,
        jsc: { blackhole(jPow.description.count) },
        att: { blackhole(aPow.description.count) }),
    Case(name: "parse 10,000 decimal digits, 100 times", runs: 3,
        jsc: { for _ in 0..<100 { blackhole(JSBigInt(digits10k)!) } },
        att: { for _ in 0..<100 { blackhole(BigInt(digits10k)!) } }),
]

// MARK: - Run, emit a Markdown table

// sanity: both libraries agree before we race them
precondition(jBig.description == aBig.description, "libraries disagree!")
precondition(jPow.description == aPow.description, "libraries disagree!")

print("| Benchmark | JSCBigInt | attaswift/BigInt | ratio (JSC/atta) |")
print("|:--|--:|--:|--:|")
for c in cases {
    let tj = bestOf(c.runs, c.jsc)
    let ta = bestOf(c.runs, c.att)
    let ratio = String(format: "%.2f×", tj / ta)
    print("| \(c.name) | \(fmt(tj)) | \(fmt(ta)) | \(ratio) |")
}
