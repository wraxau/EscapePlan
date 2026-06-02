import Foundation

extension Decimal {
    var ceiled: Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, 0, .up)
        return result
    }

    var ceiledString: String {
        let ns = NSDecimalNumber(decimal: ceiled)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return formatter.string(from: ns) ?? "\(ns.intValue)"
    }
}
