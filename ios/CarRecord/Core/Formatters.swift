import Foundation

/// 统一货币格式化，避免各页面重复创建 NumberFormatter。
enum CurrencyFormatter {
    static func value(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}

/// 统一日期格式化，保证全局中文日期展示一致。
enum DateTextFormatter {
    static func shortDate(_ date: Date) -> String {
        let formatter = AppDateContext.makeDisplayFormatter("yyyy-MM-dd")
        return formatter.string(from: date)
    }
}

/// 里程分段工具：统一“万 + 千”两段选择与整数公里之间的转换。
enum MileageSegmentFormatter {
    static func mileage(wan: Int, qian: Int, bai: Int) -> Int {
        (wan * 10_000) + (qian * 1_000) + (bai * 100)
    }

    static func segments(from mileage: Int) -> (wan: Int, qian: Int, bai: Int) {
        let safeMileage = max(0, mileage)
        let wan = min(max(safeMileage / 10_000, 0), 99)
        let qian = min(max((safeMileage % 10_000) / 1_000, 0), 9)
        let bai = min(max((safeMileage % 1_000) / 100, 0), 9)
        return (wan, qian, bai)
    }

    /// 统一里程三段文案，避免页面各自拼接造成展示不一致。
    static func text(wan: Int, qian: Int, bai: Int) -> String {
        "\(wan)万 \(qian)千 \(bai)百"
    }
}

/// 车龄格式化：按年计算并保留 1 位小数，避免手动维护车龄字段。
enum CarAgeFormatter {
    static func yearsText(from date: Date, now: Date = AppDateContext.now()) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        let years = interval / (365.25 * 24 * 60 * 60)
        return String(format: "%.1f", years)
    }
}

/// 车辆文案格式化：统一“品牌 + 车型”展示。
enum CarDisplayFormatter {
    static func name(_ car: Car) -> String {
        return "\(car.brand) \(car.modelName)"
    }
}
