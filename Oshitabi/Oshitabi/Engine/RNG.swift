import Foundation

/// 保存・再現できる乱数（同じ種なら同じ結果になる）。冒険の途中保存やテストに使う。
struct SeededRNG: RandomNumberGenerator, Codable, Hashable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<upper の整数
    mutating func int(_ upper: Int) -> Int {
        guard upper > 0 else { return 0 }
        return Int(next() % UInt64(upper))
    }

    /// 0...1 の小数
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func chance(_ p: Double) -> Bool { unit() < p }

    mutating func pick<T>(_ items: [T]) -> T? {
        items.isEmpty ? nil : items[int(items.count)]
    }

    mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            items.swapAt(i, int(i + 1))
        }
    }
}
