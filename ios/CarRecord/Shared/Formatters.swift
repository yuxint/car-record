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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 日期+时间展示，满足保养时间记录需求。
    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

/// 里程分段工具：统一“万 + 千”两段选择与整数公里之间的转换。
enum MileageSegmentFormatter {
    static func mileage(wan: Int, qian: Int) -> Int {
        (wan * 10_000) + (qian * 1_000)
    }

    static func segments(from mileage: Int) -> (wan: Int, qian: Int) {
        let safeMileage = max(0, mileage)
        let wan = min(max(safeMileage / 10_000, 0), 99)
        let qian = min(max((safeMileage % 10_000) / 1_000, 0), 9)
        return (wan, qian)
    }

    static func text(wan: Int, qian: Int) -> String {
        "\(mileage(wan: wan, qian: qian)) km"
    }
}

/// 车龄格式化：按年计算并保留 1 位小数，避免手动维护车龄字段。
enum CarAgeFormatter {
    static func yearsText(from date: Date, now: Date = .now) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        let years = interval / (365.25 * 24 * 60 * 60)
        return String(format: "%.1f", years)
    }
}
