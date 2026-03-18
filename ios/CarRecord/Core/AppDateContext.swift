import Foundation

/// 全局日期展示上下文：统一中文区域，并支持“系统时间/手动日期”切换。
enum AppDateContext {
    static let locale = Locale(identifier: "zh_Hans_CN")
    static let useManualNowStorageKey = "app_date_use_manual_now"
    static let manualNowTimestampStorageKey = "app_date_manual_now_timestamp"

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = .current
        return calendar
    }

    /// 生成用户可读日期格式器（系统时区 + 中文区域）。
    static func makeDisplayFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }

    /// 格式化短日期（yyyy-MM-dd）。
    static func formatShortDate(_ date: Date) -> String {
        let formatter = makeDisplayFormatter("yyyy-MM-dd")
        return formatter.string(from: date)
    }

    /// 业务“当前时间”入口：支持临时切换为用户手动日期，便于本地调试提醒逻辑。
    static func now() -> Date {
        if isManualNowEnabled() {
            return manualNowDate()
        }
        return Date()
    }

    /// 是否启用手动日期（临时设置）。
    static func isManualNowEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: useManualNowStorageKey)
    }

    /// 读取手动日期；无有效值时兜底为今天，避免配置异常导致空值。
    static func manualNowDate() -> Date {
        let timestamp = UserDefaults.standard.double(forKey: manualNowTimestampStorageKey)
        guard timestamp > 0 else { return calendar.startOfDay(for: Date()) }
        let storedDate = Date(timeIntervalSince1970: timestamp)
        return calendar.startOfDay(for: storedDate)
    }

    /// 持久化手动日期：统一归一化到当天 00:00，保证全局按“日期维度”一致计算。
    static func setManualNowDate(_ date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        UserDefaults.standard.set(normalizedDate.timeIntervalSince1970, forKey: manualNowTimestampStorageKey)
    }

    /// 启用/关闭手动日期：关闭时仅停用，不清空用户上次选择，便于再次开启复用。
    static func setManualNowEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: useManualNowStorageKey)
    }
}
