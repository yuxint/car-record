import Foundation
import SwiftData

extension MaintenanceItemConfig {
    /// 同步记录与“周期-项目”关系：用于维持数据库硬唯一约束。
    static func syncCycleAndRelations(for record: MaintenanceRecord, in modelContext: ModelContext) {
        let existingRelations = Array(record.itemRelations)
        for relation in existingRelations {
            modelContext.delete(relation)
        }

        guard let carID = record.car?.id else { return }

        let cycleDay = Calendar.current.startOfDay(for: record.date)
        if record.date != cycleDay {
            record.date = cycleDay
        }
        let normalizedCycleKey = MaintenanceRecord.cycleKey(carID: carID, date: cycleDay)
        if record.cycleKey != normalizedCycleKey {
            record.cycleKey = normalizedCycleKey
        }

        let uniqueItemIDs = uniqueItemIDsPreservingOrder(from: record.itemIDsRaw)
        let normalizedRaw = joinItemIDs(uniqueItemIDs)
        if record.itemIDsRaw != normalizedRaw {
            record.itemIDsRaw = normalizedRaw
        }

        for itemID in uniqueItemIDs {
            modelContext.insert(
                MaintenanceRecordItem(
                    cycleItemKey: MaintenanceRecordItem.cycleItemKey(
                        cycleKey: normalizedCycleKey,
                        itemID: itemID
                    ),
                    itemID: itemID,
                    record: record
                )
            )
        }
    }

    /// 过滤重复项目ID，保持原有顺序。
    private static func uniqueItemIDsPreservingOrder(from raw: String) -> [UUID] {
        var seen = Set<UUID>()
        var unique: [UUID] = []
        for itemID in parseItemIDs(raw) where seen.contains(itemID) == false {
            seen.insert(itemID)
            unique.append(itemID)
        }
        return unique
    }
}
