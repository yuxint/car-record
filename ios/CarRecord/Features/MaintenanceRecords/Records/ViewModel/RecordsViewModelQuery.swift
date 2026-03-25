import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class RecordsViewModel: ObservableObject {
    @Published var displayMode: LogDisplayMode = .byDate
    @Published var editingTarget: MaintenanceRecordEditTarget?
    @Published var cycleFilters = LogFilterState()
    @Published var itemFilters = LogFilterState()
    @Published var isCycleFilterExpanded = false
    @Published var isItemFilterExpanded = false
    @Published var selectionSheetTarget: FilterSelectionSheetTarget?
    @Published var selectionDraftIDs: Set<UUID> = []
    @Published var hasInteractedWithSelectionDraft = false
    @Published var saveErrorMessage = ""
    @Published var isSaveErrorAlertPresented = false
    @Published var isAddingMaintenanceRecord = false

    @Published private(set) var appliedCarIDRaw: String {
        didSet {
            UserDefaults.standard.set(appliedCarIDRaw, forKey: AppliedCarContext.storageKey)
        }
    }

    init() {
        appliedCarIDRaw = UserDefaults.standard.string(forKey: AppliedCarContext.storageKey) ?? ""
    }

    func openEditRecord(_ record: MaintenanceRecord, lockedItemID: UUID? = nil) {
        editingTarget = MaintenanceRecordEditTarget(record: record, lockedItemID: lockedItemID)
    }

    func cycleSectionTitle(filteredDateGroups: [MaintenanceDateGroup]) -> String {
        "按周期展示（\(filteredDateGroups.count)条）"
    }

    func itemSectionTitle(filteredItemRows: [MaintenanceItemRow]) -> String {
        "按保养项目展示（\(filteredItemRows.count)条）"
    }

    func yearFilterSummary(selectedYear: Int?) -> String {
        guard let selectedYear else { return "全部年份" }
        return "\(selectedYear)年"
    }

    func carFilterSummary(selectedIDs: Set<UUID>) -> String {
        if selectedIDs.isEmpty { return "全部车辆" }
        return "已选\(selectedIDs.count)辆"
    }

    func itemFilterSummary(selectedIDs: Set<UUID>) -> String {
        if selectedIDs.isEmpty { return "全部项目" }
        return "已选\(selectedIDs.count)项"
    }

    func filterSummary(filters: LogFilterState, mode: LogDisplayMode) -> String {
        var activeCount = 0
        if filters.selectedItemIDs.isEmpty == false {
            activeCount += 1
        }
        if mode == .byDate {
            if filters.selectedCarIDs.isEmpty == false {
                activeCount += 1
            }
            if filters.selectedYear != nil {
                activeCount += 1
            }
        }
        if activeCount == 0 {
            return "未设置"
        }
        return "已设置\(activeCount)项"
    }
}

extension RecordsViewModel {
    func appliedCarID(cars: [Car]) -> UUID? {
        AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars)
    }

    func scopedCars(cars: [Car]) -> [Car] {
        guard let appliedCarID = appliedCarID(cars: cars) else { return [] }
        return cars.filter { $0.id == appliedCarID }
    }

    func scopedMaintenanceRecords(cars: [Car], serviceRecords: [MaintenanceRecord]) -> [MaintenanceRecord] {
        guard let appliedCarID = appliedCarID(cars: cars) else { return [] }
        return serviceRecords.filter { $0.car?.id == appliedCarID }
    }

    func scopedServiceItemOptions(cars: [Car], serviceItemOptions: [MaintenanceItemOption]) -> [MaintenanceItemOption] {
        CoreConfig.scopedOptions(serviceItemOptions, carID: appliedCarID(cars: cars))
    }

    func filteredDateGroups(
        cars: [Car],
        serviceRecords: [MaintenanceRecord],
        serviceItemOptions: [MaintenanceItemOption]
    ) -> [MaintenanceDateGroup] {
        let scopedRecords = scopedMaintenanceRecords(cars: cars, serviceRecords: serviceRecords)
        let recordsForGrouping = scopedRecords.filter { record in
            guard record.car != nil else { return false }
            return matchesCycleFilters(record: record, filters: cycleFilters)
        }
        let grouped = buildDateGroups(
            from: recordsForGrouping,
            cars: cars,
            serviceItemOptions: serviceItemOptions
        )
        return grouped.filter { group in
            matchesCycleItemFilter(group: group, selectedItemIDs: cycleFilters.selectedItemIDs)
        }
    }

    func filteredItemRows(
        cars: [Car],
        serviceRecords: [MaintenanceRecord],
        serviceItemOptions: [MaintenanceItemOption]
    ) -> [MaintenanceItemRow] {
        let scopedRecords = scopedMaintenanceRecords(cars: cars, serviceRecords: serviceRecords)
            .filter { $0.car != nil }
        return buildItemRows(
            from: scopedRecords,
            cars: cars,
            serviceItemOptions: serviceItemOptions
        )
        .filter { row in
            matchesItemSelection(rowItemID: row.itemID, selectedItemIDs: itemFilters.selectedItemIDs)
        }
    }

    func buildDateGroups(
        from records: [MaintenanceRecord],
        cars: [Car],
        serviceItemOptions: [MaintenanceItemOption]
    ) -> [MaintenanceDateGroup] {
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
                let scopedOptions = scopedServiceItemOptions(cars: cars, serviceItemOptions: serviceItemOptions)
                let nameByID = Dictionary(uniqueKeysWithValues: scopedOptions.map { ($0.id, $0.name) })
                let orderByID = naturalItemOrderIndexByID(cars: cars, serviceItemOptions: serviceItemOptions)
                let sortedItemIDs = uniqueItemIDs.sorted { lhs, rhs in
                    let lhsOrder = orderByID[lhs, default: Int.max]
                    let rhsOrder = orderByID[rhs, default: Int.max]
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

    func buildItemRows(
        from records: [MaintenanceRecord],
        cars: [Car],
        serviceItemOptions: [MaintenanceItemOption]
    ) -> [MaintenanceItemRow] {
        let scopedOptions = scopedServiceItemOptions(cars: cars, serviceItemOptions: serviceItemOptions)
        let nameByID = Dictionary(uniqueKeysWithValues: scopedOptions.map { ($0.id, $0.name) })

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

    func presentSelectionSheet(mode: LogDisplayMode, kind: FilterSelectionKind) {
        let current = currentSelectedIDs(mode: mode, kind: kind)
        hasInteractedWithSelectionDraft = false
        selectionDraftIDs = current
        selectionSheetTarget = FilterSelectionSheetTarget(mode: mode, kind: kind)
    }

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

    func selectionOptions(
        for kind: FilterSelectionKind,
        cars: [Car],
        serviceItemOptions: [MaintenanceItemOption]
    ) -> [FilterSelectionOption] {
        switch kind {
        case .car:
            return scopedCars(cars: cars).map { car in
                FilterSelectionOption(
                    id: car.id,
                    name: CarDisplayFormatter.name(car)
                )
            }
        case .item:
            return sortedSelectionItemOptions(cars: cars, serviceItemOptions: serviceItemOptions).map { option in
                FilterSelectionOption(
                    id: option.id,
                    name: option.name
                )
            }
        }
    }

    func sortedSelectionItemOptions(cars: [Car], serviceItemOptions: [MaintenanceItemOption]) -> [MaintenanceItemOption] {
        let appliedCar = scopedCars(cars: cars).first
        let visibleOptions = CoreConfig.filterDisabledOptions(
            scopedServiceItemOptions(cars: cars, serviceItemOptions: serviceItemOptions),
            disabledItemIDsRaw: appliedCar?.disabledItemIDsRaw ?? "",
            includeDisabled: false
        )
        return CoreConfig.sortedOptions(
            visibleOptions,
            brand: appliedCar?.brand,
            modelName: appliedCar?.modelName
        )
    }

    func naturalItemOrderIndexByID(cars: [Car], serviceItemOptions: [MaintenanceItemOption]) -> [UUID: Int] {
        let appliedCar = scopedCars(cars: cars).first
        let naturalOptions = CoreConfig.sortedOptions(
            scopedServiceItemOptions(cars: cars, serviceItemOptions: serviceItemOptions),
            brand: appliedCar?.brand,
            modelName: appliedCar?.modelName
        )
        return Dictionary(uniqueKeysWithValues: naturalOptions.enumerated().map { ($1.id, $0) })
    }

    func syncAppliedCarSelection(cars: [Car]) {
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    func normalizeFilterSelectionsForAppliedCar(cars: [Car]) {
        let validCarIDs = Set(scopedCars(cars: cars).map(\.id))
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

    func cycleYearOptions(cars: [Car], serviceRecords: [MaintenanceRecord]) -> [Int] {
        let years = scopedMaintenanceRecords(cars: cars, serviceRecords: serviceRecords)
            .map { Calendar.current.component(.year, from: $0.date) }
        return Array(Set(years)).sorted(by: >)
    }
}
