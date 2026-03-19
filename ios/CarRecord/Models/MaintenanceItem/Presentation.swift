import Foundation

extension MaintenanceItemConfig {
    /// 生成提醒规则文本，用于列表摘要展示。
    static func reminderSummary(for option: MaintenanceItemOption) -> String {
        var parts: [String] = []

        if option.remindByMileage, option.mileageInterval > 0 {
            parts.append("\(option.mileageInterval) km")
        }

        if option.remindByTime, option.monthInterval > 0 {
            let years = Double(option.monthInterval) / 12.0
            if years.truncatingRemainder(dividingBy: 1) == 0 {
                parts.append("\(Int(years))年")
            } else {
                parts.append("\(String(format: "%.1f", years))年")
            }
        }

        let reminderText = parts.isEmpty ? "未设置" : parts.joined(separator: " / ")
        let thresholds = normalizedProgressThresholds(
            warning: option.warningStartPercent,
            danger: option.dangerStartPercent
        )
        return "\(reminderText) · 阈值\(thresholds.warning)%/\(thresholds.danger)%"
    }

    /// 统一校正颜色阈值，保证“黄色阈值 < 红色阈值”。
    static func normalizedProgressThresholds(warning: Int, danger: Int) -> (warning: Int, danger: Int) {
        let safeWarning = max(1, warning)
        let safeDanger = max(safeWarning + 1, danger)
        return (safeWarning, safeDanger)
    }
}
