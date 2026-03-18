import SwiftUI

extension DashboardView {
    /// 车辆分组：每辆车下展示全部保养项目。
    var carSections: [DashboardCarSection] {
        let options = sortedMaintenanceItemOptions
        let logIndex = DashboardUseCase.buildLatestLogIndex(records: scopedMaintenanceRecords)
        let firstMaintenanceIndex = DashboardUseCase.buildFirstMaintenanceLogIndex(records: scopedMaintenanceRecords)
        let now = AppDateContext.now()

        return scopedCars.compactMap { car in
            guard firstMaintenanceIndex[car.id] != nil else {
                return nil
            }

            let rows = options.map { option in
                let key = DashboardUseCase.latestLogKey(carID: car.id, itemID: option.id)
                return DashboardUseCase.buildReminderRow(
                    car: car,
                    option: option,
                    itemLatestLog: logIndex[key],
                    now: now,
                    calendar: .current
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
    var sortedMaintenanceItemOptions: [MaintenanceItemOption] {
        MaintenanceItemCatalog.naturalSortedOptions(serviceItemOptions)
    }

    /// 当前已应用车辆：无有效已应用ID时自动回退到首辆车。
    var appliedCarID: UUID? {
        AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 概览页只读取当前已应用车型。
    var scopedCars: [Car] {
        guard let appliedCarID else { return [] }
        return cars.filter { $0.id == appliedCarID }
    }

    /// 概览页记录也按当前已应用车型隔离。
    var scopedMaintenanceRecords: [MaintenanceRecord] {
        guard let appliedCarID else { return [] }
        return serviceRecords.filter { $0.car?.id == appliedCarID }
    }

    /// 同步并修正“已应用车型”持久化值，避免删除车辆后引用失效。
    func syncAppliedCarSelection() {
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    @ViewBuilder
    func reminderRow(_ row: DashboardReminderRow) -> some View {
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
