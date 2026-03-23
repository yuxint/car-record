import SwiftUI
import SwiftData

extension RecordsView {
    /// 分区标题：展示“按周期”统计数量（按分组条数统计）。
    var cycleSectionTitle: String {
        "按周期展示（\(filteredDateGroups.count)条）"
    }

    /// 分区标题：展示“按项目”统计数量（按项目行数统计）。
    var itemSectionTitle: String {
        "按保养项目展示（\(filteredItemRows.count)条）"
    }

    /// “按周期”视图使用的过滤结果：先按记录过滤，再按天聚合。
    var filteredDateGroups: [MaintenanceDateGroup] {
        let recordsForGrouping = scopedMaintenanceRecords.filter { record in
            guard record.car != nil else { return false }
            return matchesCycleFilters(record: record, filters: cycleFilters)
        }
        let grouped = buildDateGroups(from: recordsForGrouping)
        return grouped.filter { group in
            matchesCycleItemFilter(group: group, selectedItemIDs: cycleFilters.selectedItemIDs)
        }
    }

    /// “按项目”视图使用的过滤结果：先按通用条件过滤记录，再按项目展开并做项目筛选。
    var filteredItemRows: [MaintenanceItemRow] {
        buildItemRows(
            from: scopedMaintenanceRecords.filter { $0.car != nil }
        )
            .filter { row in
                matchesItemSelection(rowItemID: row.itemID, selectedItemIDs: itemFilters.selectedItemIDs)
            }
    }

    /// 按日期分组并倒序，自动合并同一天的保养记录。
    func buildDateGroups(from records: [MaintenanceRecord]) -> [MaintenanceDateGroup] {
        let grouped = Dictionary(grouping: records) { record in
            Calendar.current.startOfDay(for: record.date)
        }

        return grouped
            .map { date, groupRecords in
                var seenItemIDs = Set<UUID>()
                let uniqueItemIDs = groupRecords
                    .flatMap { CoreConfig.parseItemIDs($0.itemIDsRaw) }
                    .filter { itemID in
                        if seenItemIDs.contains(itemID) {
                            return false
                        }
                        seenItemIDs.insert(itemID)
                        return true
                    }
                let nameByID = Dictionary(uniqueKeysWithValues: serviceItemOptions.map { ($0.id, $0.name) })
                let sortedItemIDs = uniqueItemIDs.sorted { lhs, rhs in
                    let lhsOrder = naturalItemOrderIndexByID[lhs, default: Int.max]
                    let rhsOrder = naturalItemOrderIndexByID[rhs, default: Int.max]
                    if lhsOrder != rhsOrder {
                        return lhsOrder < rhsOrder
                    }
                    return lhs.uuidString < rhs.uuidString
                }
                let sortedItemNames = sortedItemIDs.compactMap { nameByID[$0] }
                return MaintenanceDateGroup(
                    date: date,
                    records: groupRecords.sorted { lhs, rhs in
                        if lhs.date != rhs.date {
                            return lhs.date > rhs.date
                        }
                        if lhs.mileage != rhs.mileage {
                            return lhs.mileage > rhs.mileage
                        }
                        return lhs.id.uuidString < rhs.id.uuidString
                    },
                    itemSummary: sortedItemNames.isEmpty ? "未标注项目" : sortedItemNames.joined(separator: "、")
                )
            }
            .sorted { $0.date > $1.date } 
    }

    /// 展开“按项目展示”时使用的行数据：
    /// 1) 按保养时间倒序；
    /// 2) 同一保养时间时按里程倒序，确保高里程排前面。
    func buildItemRows(from records: [MaintenanceRecord]) -> [MaintenanceItemRow] {
        let nameByID = Dictionary(uniqueKeysWithValues: serviceItemOptions.map { ($0.id, $0.name) })

        return records.flatMap { record in
            let itemIDs = CoreConfig.parseItemIDs(record.itemIDsRaw)
            guard itemIDs.isEmpty == false else { return [MaintenanceItemRow]() }

            return itemIDs.enumerated().compactMap { index, itemID in
                guard let itemName = nameByID[itemID] else { return nil }
                return MaintenanceItemRow(
                    id: "\(record.id.uuidString)-\(index)-\(itemID.uuidString)",
                    itemID: itemID,
                    itemName: itemName,
                    record: record
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.record.date != rhs.record.date {
                return lhs.record.date > rhs.record.date
            }
            if lhs.record.mileage != rhs.record.mileage {
                return lhs.record.mileage > rhs.record.mileage
            }
            if lhs.itemName != rhs.itemName {
                return lhs.itemName.localizedStandardCompare(rhs.itemName) == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }


    /// 打开多选弹窗：读取当前筛选为草稿，改动在点击“应用”前不会影响列表结果。
    func presentSelectionSheet(mode: LogDisplayMode, kind: FilterSelectionKind) {
        let current = currentSelectedIDs(mode: mode, kind: kind)
        hasInteractedWithSelectionDraft = false
        selectionDraftIDs = current
        selectionSheetTarget = FilterSelectionSheetTarget(mode: mode, kind: kind)
    }

    /// 当前筛选集合读取：按展示模式和筛选类型定位到对应的状态字段。
    func currentSelectedIDs(mode: LogDisplayMode, kind: FilterSelectionKind) -> Set<UUID> {
        switch (mode, kind) {
        case (.byDate, .car):
            return cycleFilters.selectedCarIDs
        case (.byDate, .item):
            return cycleFilters.selectedItemIDs
        case (.byItem, .car):
            return itemFilters.selectedCarIDs
        case (.byItem, .item):
            return itemFilters.selectedItemIDs
        }
    }

    /// 可选项列表：车辆/项目复用同一套多选弹窗。
    func selectionOptions(for kind: FilterSelectionKind) -> [FilterSelectionOption] {
        switch kind {
        case .car:
            return scopedCars.map { car in
                FilterSelectionOption(
                    id: car.id,
                    name: CarDisplayFormatter.name(car)
                )
            }
        case .item:
            return sortedSelectionItemOptions.map { option in
                FilterSelectionOption(
                    id: option.id,
                    name: option.name
                )
            }
        }
    }

    /// 筛选弹窗项目顺序：与“新增/编辑保养”保持一致，避免同类页面排序规则不一致。
    var sortedSelectionItemOptions: [MaintenanceItemOption] {
        CoreConfig.sortedSelectionOptions(
            options: serviceItemOptions,
            records: scopedMaintenanceRecords
        )
    }

    /// 项目自然顺序索引：用于“按周期”项目摘要排序稳定且与项目管理顺序一致。
    var naturalItemOrderIndexByID: [UUID: Int] {
        let naturalOptions = CoreConfig.naturalSortedOptions(serviceItemOptions)
        return Dictionary(uniqueKeysWithValues: naturalOptions.enumerated().map { ($1.id, $0) })
    }
    /// 当前已应用车型ID：若历史值失效，自动回退到首辆车。
    var appliedCarID: UUID? {
        AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 记录页可见车辆集合：仅保留当前已应用车型。
    var scopedCars: [Car] {
        guard let appliedCarID else { return [] }
        return cars.filter { $0.id == appliedCarID }
    }

    /// 记录页可见记录集合：按当前已应用车型隔离。
    var scopedMaintenanceRecords: [MaintenanceRecord] {
        guard let appliedCarID else { return [] }
        return serviceRecords.filter { $0.car?.id == appliedCarID }
    }

    /// 同步修正应用车型持久化值，避免删除车辆后指向失效。
    func syncAppliedCarSelection() {
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 车型切换后清理旧筛选，避免残留“已选其他车辆”导致列表误空。
    func normalizeFilterSelectionsForAppliedCar() {
        let validCarIDs = Set(scopedCars.map(\.id))
        guard validCarIDs.isEmpty == false else {
            cycleFilters.selectedCarIDs = []
            itemFilters.selectedCarIDs = []
            return
        }

        if cycleFilters.selectedCarIDs.isSubset(of: validCarIDs) == false {
            cycleFilters.selectedCarIDs = []
        }
        if itemFilters.selectedCarIDs.isSubset(of: validCarIDs) == false {
            itemFilters.selectedCarIDs = []
        }
    }


}
