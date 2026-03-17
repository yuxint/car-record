import SwiftUI
import SwiftData

/// 概览页：按“车辆 x 保养项目”展示下次保养进度百分比（时间/里程先到为准）。
struct DashboardView: View {
    @Query private var cars: [Car]
    @Query private var maintenanceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward)
    private var maintenanceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) private var appliedCarIDRaw = ""
    @State private var isAddingMaintenanceRecord = false

    var body: some View {
        List {
            if cars.isEmpty {
                Text("请先在“我的”中添加车辆。")
                    .foregroundStyle(.secondary)
            } else if carSections.isEmpty {
                Text("暂无保养记录，完成首次保养后开始提醒。")
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
        .toolbar {
            /// 无车辆时隐藏新增入口，避免进入无效新增流程。
            if scopedCars.isEmpty == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingMaintenanceRecord = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingMaintenanceRecord) {
            AddMaintenanceRecordView()
        }
        .onAppear {
            syncAppliedCarSelection()
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            syncAppliedCarSelection()
        }
    }

    /// 车辆分组：每辆车下展示全部保养项目。
    private var carSections: [DashboardCarSection] {
        let options = sortedMaintenanceItemOptions
        let logIndex = buildLatestLogIndex()
        let firstServiceIndex = buildFirstServiceLogIndex()
        let calendar = Calendar.current
        let now = AppDateContext.now()

        return scopedCars.compactMap { car in
            guard firstServiceIndex[car.id] != nil else {
                return nil
            }

            let rows = options.map { option in
                let key = latestLogKey(carID: car.id, itemID: option.id)
                return buildReminderRow(
                    car: car,
                    option: option,
                    itemLatestLog: logIndex[key],
                    now: now,
                    calendar: calendar
                )
            }
            .sorted { lhs, rhs in
                if lhs.rawProgress != rhs.rawProgress {
                    return lhs.rawProgress > rhs.rawProgress
                }
                if lhs.duePriority != rhs.duePriority {
                    return lhs.duePriority < rhs.duePriority
                }
                return lhs.itemName < rhs.itemName
            }

            return DashboardCarSection(
                id: car.id,
                title: CarDisplayFormatter.name(car),
                rows: rows
            )
        }
    }

    /// 默认项目优先，随后按创建时间排序，保持与“项目管理”页面一致。
    private var sortedMaintenanceItemOptions: [MaintenanceItemOption] {
        MaintenanceItemCatalog.naturalSortedOptions(maintenanceItemOptions)
    }

    /// 构建“车辆+项目 -> 最近一次保养记录”索引，避免重复扫描。
    private func buildLatestLogIndex() -> [String: MaintenanceRecord] {
        var index: [String: MaintenanceRecord] = [:]

        for record in scopedMaintenanceRecords {
            guard let carID = record.car?.id else { continue }

            let itemIDs = Set(MaintenanceItemCatalog.parseItemIDs(record.itemIDsRaw))
            for itemID in itemIDs {
                let key = latestLogKey(carID: carID, itemID: itemID)
                if let existing = index[key] {
                    /// “最近一次”先比日期；同一天多条记录时再比里程，避免基准误判。
                    if existing.date > record.date {
                        continue
                    }
                    if existing.date == record.date, existing.mileage >= record.mileage {
                        continue
                    }
                }
                index[key] = record
            }
        }

        return index
    }

    /// 车辆首保索引：取该车最早一条保养记录，作为“首保已完成”后的统一兜底基准。
    private func buildFirstServiceLogIndex() -> [UUID: MaintenanceRecord] {
        var index: [UUID: MaintenanceRecord] = [:]

        for record in scopedMaintenanceRecords {
            guard let carID = record.car?.id else { continue }
            if let existing = index[carID], existing.date <= record.date {
                continue
            }
            index[carID] = record
        }

        return index
    }

    private func latestLogKey(carID: UUID, itemID: UUID) -> String {
        "\(carID.uuidString)|\(itemID.uuidString)"
    }

    /// 计算单个项目的进度：时间/里程谁进度更高（意味着谁先到）就采用谁。
    private func buildReminderRow(
        car: Car,
        option: MaintenanceItemOption,
        itemLatestLog: MaintenanceRecord?,
        now: Date,
        calendar: Calendar
    ) -> DashboardReminderRow {
        /// 时间提醒基准：
        /// 有该项目历史记录时按该项目最近一次计算；否则按车辆上路日期计算。
        let timeBaselineDate = itemLatestLog?.date ?? car.purchaseDate

        /// 里程提醒基准：
        /// 有该项目历史记录时按该项目最近一次；若从未做过该项目，按总里程起算（基准为 0）。
        let mileageBaseline = itemLatestLog?.mileage ?? 0

        var mileageProgress: Double?
        var mileageRemaining: Int?
        if option.remindByMileage, option.mileageInterval > 0 {
            let usedMileage = max(0, car.mileage - mileageBaseline)
            mileageProgress = Double(usedMileage) / Double(option.mileageInterval)
            mileageRemaining = option.mileageInterval - usedMileage
        }

        var timeProgress: Double?
        var daysRemaining: Int?
        if option.remindByTime, option.monthInterval > 0 {
            let dueDate = calendar.date(byAdding: .month, value: option.monthInterval, to: timeBaselineDate) ?? timeBaselineDate
            let totalInterval = dueDate.timeIntervalSince(timeBaselineDate)
            let elapsed = now.timeIntervalSince(timeBaselineDate)

            if totalInterval > 0 {
                timeProgress = elapsed / totalInterval
            } else {
                timeProgress = 1
            }

            daysRemaining = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
        }

        let rawProgress: Double
        let duePriority: Double
        if let mileageProgress, let timeProgress {
            if mileageProgress >= timeProgress {
                rawProgress = mileageProgress
                duePriority = Double(option.mileageInterval)
            } else {
                rawProgress = timeProgress
                duePriority = Double(option.monthInterval) * 30
            }
        } else if let mileageProgress {
            rawProgress = mileageProgress
            duePriority = Double(option.mileageInterval)
        } else if let timeProgress {
            rawProgress = timeProgress
            duePriority = Double(option.monthInterval) * 30
        } else {
            rawProgress = 0
            duePriority = .greatestFiniteMagnitude
        }

        var detailTexts: [String] = []
        if let mileageRemaining {
            detailTexts.append(
                ReminderStrategy.mileage(
                    remaining: mileageRemaining
                ).detailText
            )
        }
        if let daysRemaining {
            detailTexts.append(
                ReminderStrategy.time(
                    remainingDays: daysRemaining
                ).detailText
            )
        }
        if detailTexts.isEmpty {
            detailTexts = [ReminderStrategy.none.detailText]
        }

        let clampedProgress = min(max(rawProgress, 0), 1)
        let rawPercent = max(0, rawProgress * 100)
        let percent = Int(rawPercent.rounded())
        let thresholds = MaintenanceItemCatalog.normalizedProgressThresholds(
            warning: option.warningStartPercent,
            danger: option.dangerStartPercent
        )
        let progressColorLevel: ReminderProgressColorLevel
        if rawPercent < Double(thresholds.warning) {
            progressColorLevel = .normal
        } else if rawPercent <= Double(thresholds.danger) {
            progressColorLevel = .warning
        } else {
            progressColorLevel = .danger
        }

        return DashboardReminderRow(
            id: latestLogKey(carID: car.id, itemID: option.id),
            itemName: option.name,
            rawProgress: rawProgress,
            duePriority: duePriority,
            displayProgress: clampedProgress,
            progressText: "\(percent)%",
            detailTexts: detailTexts,
            progressColorLevel: progressColorLevel
        )
    }

    /// 当前已应用车辆：无有效已应用ID时自动回退到首辆车。
    private var appliedCarID: UUID? {
        AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 概览页只读取当前已应用车型。
    private var scopedCars: [Car] {
        guard let appliedCarID else { return [] }
        return cars.filter { $0.id == appliedCarID }
    }

    /// 概览页记录也按当前已应用车型隔离。
    private var scopedMaintenanceRecords: [MaintenanceRecord] {
        guard let appliedCarID else { return [] }
        return maintenanceRecords.filter { $0.car?.id == appliedCarID }
    }

    /// 同步并修正“已应用车型”持久化值，避免删除车辆后引用失效。
    private func syncAppliedCarSelection() {
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
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
                    .foregroundStyle(row.progressColorLevel.color)
            }

            LinearProgressBar(
                value: row.displayProgress,
                color: row.progressColorLevel.color
            )

            ForEach(Array(row.detailTexts.enumerated()), id: \.offset) { _, detailText in
                Text(detailText)
                    .font(.footnote)
                    .foregroundStyle(row.progressColorLevel.secondaryColor)
            }
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
    let duePriority: Double
    let displayProgress: Double
    let progressText: String
    let detailTexts: [String]
    let progressColorLevel: ReminderProgressColorLevel
}

/// 进度判定策略：时间/里程谁先到期，就展示谁的剩余信息。
private enum ReminderStrategy {
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
            return "按里程提醒：已超 \(overMileageDistanceText(for: abs(remaining)))"
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

    /// 里程展示规则：>=1万时显示“几万几千公里”，千位为 0 时省略。
    private func mileageDistanceText(for value: Int) -> String {
        if value >= 10_000 {
            return formattedMileageByWanQian(value)
        }
        return "\(value)公里"
    }

    /// 里程超期规则：>=1万时显示“几万几千公里”，千位为 0 时省略。
    private func overMileageDistanceText(for value: Int) -> String {
        if value >= 10_000 {
            return formattedMileageByWanQian(value)
        }
        return "\(value)公里"
    }

    /// 时间展示规则：<1个月显示天，<1年显示月，>=1年显示“年+月”（月为0时仅显示年）。
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

    /// 把公里值转为“几万几千公里”文案，千位为 0 时省略千位。
    private func formattedMileageByWanQian(_ value: Int) -> String {
        let wan = value / 10_000
        let qian = (value % 10_000) / 1_000
        if qian == 0 {
            return "\(wan)万公里"
        }
        return "\(wan)万\(qian)千公里"
    }
}

/// 概览页进度颜色等级：默认绿色，100%~阈值黄色，超过上限红色。
private enum ReminderProgressColorLevel {
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
        /// 进度条下方说明文案统一使用次级文字色，避免不同状态下可读性不一致。
        .secondary
    }
}

/// 自绘进度条：在 0% 时只显示背景，不渲染前景色填充。
private struct LinearProgressBar: View {
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

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }
}
