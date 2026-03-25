import Foundation

/// 保养提醒页车辆分组模型。
struct MaintenanceReminderCarSection: Identifiable {
    let id: UUID
    let title: String
    let rows: [MaintenanceReminderRow]
}

/// 保养提醒页单行项目进度模型。
struct MaintenanceReminderRow: Identifiable {
    let id: String
    let itemName: String
    let rawProgress: Double
    let duePriority: Double
    let displayProgress: Double
    let progressText: String
    let detailTexts: [String]
    let progressColorLevel: ReminderProgressColorLevel
}

/// 进度判定策略：时间/里程谁先到期，就展示谁的剩余信息。
enum ReminderStrategy {
    case mileage(remaining: Int)
    case time(remainingDays: Int)
    case none

    var detailText: String {
        switch self {
        case .mileage(let remaining):
            if remaining > 0 {
                return "按里程提醒：距离下次约 \(mileageDistanceText(for: remaining))"
            }
            if remaining == 0 {
                return "按里程提醒：今日到期"
            }
            return "按里程提醒：已超 \(mileageDistanceText(for: abs(remaining)))"
        case .time(let remainingDays):
            if remainingDays > 0 {
                return "按时间提醒：距离下次约 \(timeDistanceText(for: remainingDays))"
            }
            if remainingDays == 0 {
                return "按时间提醒：今日到期"
            }
            return "按时间提醒：已超 \(timeDistanceText(for: abs(remainingDays)))"
        case .none:
            return "未设置提醒规则"
        }
    }

    private func mileageDistanceText(for value: Int) -> String {
        MileageDisplayFormatter.reminderDistanceText(for: value)
    }

    private func timeDistanceText(for days: Int) -> String {
        if days < 30 {
            return "\(days)天"
        }
        if days < 365 {
            let months = max(1, Int((Double(days) / 30.0).rounded(.down)))
            return "\(months)个月"
        }

        let totalMonths = max(12, Int((Double(days) / 30.0).rounded(.down)))
        let years = totalMonths / 12
        let months = totalMonths % 12
        if months == 0 {
            return "\(years)年"
        }
        return "\(years)年\(months)个月"
    }
}

/// 保养提醒页进度颜色等级：黄色区间 (100,125)，红色从 125 起。
enum ReminderProgressColorLevel {
    case normal
    case warning
    case danger
}
