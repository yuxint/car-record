import Foundation
import SwiftUI

/// 全局日期展示上下文：统一中文区域，并支持“系统时间/手动日期”切换。
enum AppDateContext {
    static let locale = Locale(identifier: "zh_Hans_CN")
    static let useManualNowStorageKey = "app_date_use_manual_now"
    static let manualNowTimestampStorageKey = "app_date_manual_now_timestamp"

    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
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

/// 通用里程三段选择弹窗：统一“万/千/百”交互与工具栏行为。
struct MileagePickerSheetView: View {
    let title: String
    @Binding var wan: Int
    @Binding var qian: Int
    @Binding var bai: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("万", selection: $wan) {
                    ForEach(0...99, id: \.self) { value in
                        Text("\(value)万").tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("千", selection: $qian) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)千").tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("百", selection: $bai) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)百").tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认", action: onConfirm)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

/// 通用日期选择弹窗：统一图形化日期选择和“选择即应用”的行为。
struct DayDatePickerSheetView: View {
    let title: String
    let label: String
    @Binding var draftDate: Date
    let currentDate: Date
    let onApply: (Date) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker(label, selection: $draftDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: draftDate) { _, newValue in
                    onApply(newValue)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            draftDate = currentDate
                            onCancel()
                        }
                    }
                }
        }
        .presentationDetents([.height(420)])
    }
}
