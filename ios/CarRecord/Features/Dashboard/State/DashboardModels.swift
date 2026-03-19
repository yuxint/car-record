import SwiftUI

/// 概览页车辆分组模型。
struct DashboardCarSection: Identifiable {
    let id: UUID
    let title: String
    let rows: [DashboardReminderRow]
}

/// 概览页单行项目进度模型。
struct DashboardReminderRow: Identifiable {
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
        if value >= 10_000 {
            return formattedMileageByWanQian(value)
        }
        return "\(value)公里"
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

    private func formattedMileageByWanQian(_ value: Int) -> String {
        let wan = value / 10_000
        let remainder = value % 10_000
        let qian = remainder / 1_000
        let bai = (remainder % 1_000) / 100
        
        if wan > 0 {
            if qian > 0 || bai > 0 {
                let decimalValue = Double(qian * 1_000 + bai * 100) / 10_000.0
                let fullString = String(format: "%.1f", decimalValue)
                let parts = fullString.split(separator: ".")
                let decimalPart = parts.count > 1 ? String(parts[1]).replacingOccurrences(of: "^0+|0+$", with: "", options: .regularExpression) : ""
                if decimalPart.isEmpty {
                    return "\(wan)万公里"
                }
                return "\(wan).\(decimalPart)万公里"
            }
            return "\(wan)万公里"
        }
        
        if qian > 0 || bai > 0 {
            return "\(value)公里"
        }
        
        return "0公里"
    }
}

/// 概览页进度颜色等级：默认绿色，100%~阈值黄色，超过上限红色。
enum ReminderProgressColorLevel {
    case normal
    case warning
    case danger

    var color: Color {
        switch self {
        case .normal:
            return .green
        case .warning:
            return .yellow
        case .danger:
            return .red
        }
    }

    var secondaryColor: Color {
        .secondary
    }
}

/// 自绘进度条：在 0% 时只显示背景，不渲染前景色填充。
struct LinearProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                if clampedValue > 0 {
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * clampedValue)
                }
            }
        }
        .frame(height: 8)
    }

    var clampedValue: Double {
        min(max(value, 0), 1)
    }
}
