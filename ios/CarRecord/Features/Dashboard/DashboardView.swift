import SwiftUI
import SwiftData

/// 概览页：按“车辆 x 保养项目”展示下次保养进度百分比（时间/里程先到为准）。
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cars: [Car]
    @Query private var maintenanceLogs: [MaintenanceLog]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward)
    private var maintenanceItemOptions: [MaintenanceItemOption]

    var body: some View {
        List {
            if cars.isEmpty {
                Text("请先在“我的”中添加车辆。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(carSections) { section in
                    Section(section.title) {
                        ForEach(section.rows) { row in
                            reminderRow(row)
                        }
                    }
                }
            }
        }
        .navigationTitle("概览")
        .onAppear {
            /// 兜底初始化默认保养项目，避免首次进入概览时无可计算项目。
            MaintenanceItemCatalog.ensureDefaults(in: modelContext)
        }
    }

    /// 车辆分组：每辆车下展示全部保养项目。
    private var carSections: [DashboardCarSection] {
        let options = sortedMaintenanceItemOptions
        let logIndex = buildLatestLogIndex()
        let calendar = Calendar.current
        let now = Date.now

        return cars.map { car in
            let rows = options.map { option in
                let key = latestLogKey(carID: car.id, itemName: option.name)
                let latestLog = logIndex[key]
                return buildReminderRow(
                    car: car,
                    option: option,
                    latestLog: latestLog,
                    now: now,
                    calendar: calendar
                )
            }
            .sorted { lhs, rhs in
                if lhs.rawProgress != rhs.rawProgress {
                    return lhs.rawProgress > rhs.rawProgress
                }
                return lhs.itemName < rhs.itemName
            }

            return DashboardCarSection(
                id: car.id,
                title: "\(car.brand) \(car.modelName)",
                rows: rows
            )
        }
    }

    /// 默认项目优先，随后按创建时间排序，保持与“项目管理”页面一致。
    private var sortedMaintenanceItemOptions: [MaintenanceItemOption] {
        maintenanceItemOptions.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault && !rhs.isDefault
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// 构建“车辆+项目 -> 最近一次保养记录”索引，避免重复扫描。
    private func buildLatestLogIndex() -> [String: MaintenanceLog] {
        var index: [String: MaintenanceLog] = [:]

        for log in maintenanceLogs {
            guard let carID = log.car?.id else { continue }

            let items = Set(MaintenanceItemCatalog.parse(log.title))
            for item in items where !item.isEmpty {
                let key = latestLogKey(carID: carID, itemName: item)
                if let existing = index[key], existing.date >= log.date {
                    continue
                }
                index[key] = log
            }
        }

        return index
    }

    private func latestLogKey(carID: UUID, itemName: String) -> String {
        "\(carID.uuidString)|\(itemName)"
    }

    /// 计算单个项目的进度：时间/里程谁进度更高（意味着谁先到）就采用谁。
    private func buildReminderRow(
        car: Car,
        option: MaintenanceItemOption,
        latestLog: MaintenanceLog?,
        now: Date,
        calendar: Calendar
    ) -> DashboardReminderRow {
        /// 仅当存在该项目的历史记录时，才允许按里程计算进度，避免首次录入被误判超期。
        let hasBaselineLog = latestLog != nil
        let baselineDate = latestLog?.date ?? car.purchaseDate
        let baselineMileage = latestLog?.mileage ?? 0

        var mileageProgress: Double?
        var mileageRemaining: Int?
        if hasBaselineLog, option.remindByMileage, option.mileageInterval > 0 {
            let usedMileage = max(0, car.mileage - baselineMileage)
            mileageProgress = Double(usedMileage) / Double(option.mileageInterval)
            mileageRemaining = option.mileageInterval - usedMileage
        }

        var timeProgress: Double?
        var daysRemaining: Int?
        if option.remindByTime, option.monthInterval > 0 {
            let dueDate = calendar.date(byAdding: .month, value: option.monthInterval, to: baselineDate) ?? baselineDate
            let totalInterval = dueDate.timeIntervalSince(baselineDate)
            let elapsed = now.timeIntervalSince(baselineDate)

            if totalInterval > 0 {
                timeProgress = elapsed / totalInterval
            } else {
                timeProgress = 1
            }

            daysRemaining = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
        }

        let strategy: ReminderStrategy
        let rawProgress: Double
        if hasBaselineLog == false, option.remindByMileage {
            strategy = .initialRecord
            rawProgress = 0
        } else if let mileageProgress, let timeProgress {
            if mileageProgress >= timeProgress {
                strategy = .mileage(mileageRemaining ?? 0)
                rawProgress = mileageProgress
            } else {
                strategy = .time(daysRemaining ?? 0)
                rawProgress = timeProgress
            }
        } else if let mileageProgress {
            strategy = .mileage(mileageRemaining ?? 0)
            rawProgress = mileageProgress
        } else if let timeProgress {
            strategy = .time(daysRemaining ?? 0)
            rawProgress = timeProgress
        } else {
            strategy = .none
            rawProgress = 0
        }

        let clampedProgress = min(max(rawProgress, 0), 1)
        let percent = Int((clampedProgress * 100).rounded())

        return DashboardReminderRow(
            id: latestLogKey(carID: car.id, itemName: option.name),
            itemName: option.name,
            rawProgress: rawProgress,
            displayProgress: clampedProgress,
            progressText: "\(percent)%",
            detailText: strategy.detailText,
            isOverdue: rawProgress >= 1
        )
    }

    @ViewBuilder
    private func reminderRow(_ row: DashboardReminderRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.itemName)
                    .lineLimit(1)
                Spacer()
                Text(row.progressText)
                    .fontWeight(.semibold)
                    .foregroundStyle(row.isOverdue ? .red : .primary)
            }

            ProgressView(value: row.displayProgress)
                .tint(row.isOverdue ? .red : .accentColor)

            Text(row.detailText)
                .font(.footnote)
                .foregroundStyle(row.isOverdue ? .red : .secondary)
        }
        .padding(.vertical, 4)
    }
}

/// 概览页车辆分组模型。
private struct DashboardCarSection: Identifiable {
    let id: UUID
    let title: String
    let rows: [DashboardReminderRow]
}

/// 概览页单行项目进度模型。
private struct DashboardReminderRow: Identifiable {
    let id: String
    let itemName: String
    let rawProgress: Double
    let displayProgress: Double
    let progressText: String
    let detailText: String
    let isOverdue: Bool
}

/// 进度判定策略：时间/里程谁先到期，就展示谁的剩余信息。
private enum ReminderStrategy {
    case mileage(Int)
    case time(Int)
    case initialRecord
    case none

    var detailText: String {
        switch self {
        case .mileage(let remaining):
            if remaining > 0 {
                return "按里程提醒：距离下次约 \(remaining) km"
            }
            if remaining == 0 {
                return "按里程提醒：今日到期"
            }
            return "按里程提醒：已超 \(abs(remaining)) km"
        case .time(let remainingDays):
            if remainingDays > 0 {
                return "按时间提醒：距离下次约 \(remainingDays) 天"
            }
            if remainingDays == 0 {
                return "按时间提醒：今日到期"
            }
            return "按时间提醒：已超 \(abs(remainingDays)) 天"
        case .initialRecord:
            return "请先添加保养记录"
        case .none:
            return "未设置提醒规则"
        }
    }
}
