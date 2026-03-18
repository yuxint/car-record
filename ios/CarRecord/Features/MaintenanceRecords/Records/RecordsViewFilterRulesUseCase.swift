import SwiftUI
import SwiftData

extension RecordsView {
    func matchesCycleFilters(record: MaintenanceRecord, filters: LogFilterState) -> Bool {
        if filters.selectedCarIDs.isEmpty == false {
            guard let carID = record.car?.id, filters.selectedCarIDs.contains(carID) else {
                return false
            }
        }

        if let selectedYear = filters.selectedYear {
            let recordYear = Calendar.current.component(.year, from: record.date)
            if recordYear != selectedYear {
                return false
            }
        }
        return true
    }

    /// “按周期”项目筛选：只要该周期内任一记录包含选中项目，就展示该周期。
    func matchesCycleItemFilter(group: MaintenanceDateGroup, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        return group.records.contains { record in
            matchesItemSelection(itemIDsRaw: record.itemIDsRaw, selectedItemIDs: selectedItemIDs)
        }
    }

    /// “按项目”行筛选：空集合代表不过滤，非空时只展示命中的项目行。
    func matchesItemSelection(rowItemID: UUID, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        return selectedItemIDs.contains(rowItemID)
    }

    /// 字符串项目集合筛选：至少命中一个选中项目才通过。
    func matchesItemSelection(itemIDsRaw: String, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        let itemIDs = Set(MaintenanceItemCatalog.parseItemIDs(itemIDsRaw))
        guard itemIDs.isEmpty == false else { return false }
        return itemIDs.isDisjoint(with: selectedItemIDs) == false
    }

}
