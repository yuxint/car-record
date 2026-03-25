import SwiftUI

/// 保养提醒页计算逻辑：索引构建、提醒进度和文案生成。
enum MaintenanceReminderUseCase {
    /// 构建"车辆+项目 -> 最近一次保养记录"索引，避免重复扫描。
    static func buildLatestLogIndex(record: MaintenanceRecord) -> [String: MaintenanceRecord] {
        guard let carID = record.car?.id else { return [:] }

        let itemIDs = Set(CoreConfig.parseItemIDs(record.itemIDsRaw))
        var index: [String: MaintenanceRecord] = [:]

        for itemID in itemIDs {
            let key = latestLogKey(carID: carID, itemID: itemID)
            index[key] = record
        }

        return index
    }

    /// 车辆首保索引：取该车最早一条保养记录，作为"首保已完成"后的统一兜底基准。
    static func buildFirstMaintenanceLogIndex(record: MaintenanceRecord) -> [UUID: MaintenanceRecord] {
        guard let carID = record.car?.id else { return [:] }
        return [carID: record]
    }

    static func latestLogKey(carID: UUID, itemID: UUID) -> String {
        "\(carID.uuidString)|\(itemID.uuidString)"
    }

    /// 计算单个项目的进度：时间/里程谁进度更高（意味着谁先到）就采用谁。
    static func buildReminderRow(
        car: Car,
        option: MaintenanceItemOption,
        itemLatestLog: MaintenanceRecord?,
        now: Date,
        calendar: Calendar
    ) -> MaintenanceReminderRow {
        let timeBaselineDate = itemLatestLog?.date ?? car.purchaseDate
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
            detailTexts.append(ReminderStrategy.mileage(remaining: mileageRemaining).detailText)
        }
        if let daysRemaining {
            detailTexts.append(ReminderStrategy.time(remainingDays: daysRemaining).detailText)
        }
        if detailTexts.isEmpty {
            detailTexts = [ReminderStrategy.none.detailText]
        }

        let clampedProgress = min(max(rawProgress, 0), 1)
        let rawPercent = max(0, rawProgress * 100)
        let percent = Int(rawPercent.rounded())
        let progressColorLevel: ReminderProgressColorLevel
        if rawPercent >= Double(CoreConfig.warningRangeStartPercent),
           rawPercent < Double(CoreConfig.warningRangeEndExclusivePercent) {
            progressColorLevel = .warning
        } else if rawPercent >= Double(CoreConfig.dangerStartPercent) {
            progressColorLevel = .danger
        } else {
            progressColorLevel = .normal
        }

        return MaintenanceReminderRow(
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
}
