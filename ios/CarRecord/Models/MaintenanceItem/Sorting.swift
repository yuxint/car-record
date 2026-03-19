import Foundation

extension MaintenanceItemConfig {
    /// 默认项目自然顺序索引：默认项返回非空，自定义项返回空。
    static func defaultOrderIndex(for option: MaintenanceItemOption) -> Int? {
        guard let key = option.catalogKey else { return nil }
        return defaultOrderByKey[key]
    }

    /// 默认项目优先，其次按默认顺序/创建时间排序。
    static func naturalSortedOptions(_ options: [MaintenanceItemOption]) -> [MaintenanceItemOption] {
        options.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault && !rhs.isDefault
            }
            if lhs.isDefault, rhs.isDefault {
                let lhsOrder = defaultOrderIndex(for: lhs) ?? Int.max
                let rhsOrder = defaultOrderIndex(for: rhs) ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// 统计项目在记录中的使用次数（同一记录内重复项目只算 1 次）。
    static func usageCountByItemID(in records: [MaintenanceRecord]) -> [UUID: Int] {
        var counter: [UUID: Int] = [:]
        for record in records {
            let itemIDs = Set(parseItemIDs(record.itemIDsRaw))
            for itemID in itemIDs {
                counter[itemID, default: 0] += 1
            }
        }
        return counter
    }

    /// 项目选择器排序：无记录时按预设优先级；有记录时按使用频次。
    static func sortedSelectionOptions(
        options: [MaintenanceItemOption],
        records: [MaintenanceRecord]
    ) -> [MaintenanceItemOption] {
        let naturalOptions = naturalSortedOptions(options)
        var naturalOrderIndexByID: [UUID: Int] = [:]
        for (index, option) in naturalOptions.enumerated() {
            naturalOrderIndexByID[option.id] = index
        }

        if records.isEmpty {
            return naturalOptions.sorted { lhs, rhs in
                let lhsRank = preferredKeysWhenNoLog.firstIndex(of: lhs.catalogKey ?? "") ?? Int.max
                let rhsRank = preferredKeysWhenNoLog.firstIndex(of: rhs.catalogKey ?? "") ?? Int.max
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return naturalOrderIndexByID[lhs.id, default: Int.max] < naturalOrderIndexByID[rhs.id, default: Int.max]
            }
        }

        let usageCount = usageCountByItemID(in: records)
        return naturalOptions.sorted { lhs, rhs in
            let lhsCount = usageCount[lhs.id, default: 0]
            let rhsCount = usageCount[rhs.id, default: 0]
            let lhsUsed = lhsCount > 0
            let rhsUsed = rhsCount > 0

            if lhsUsed != rhsUsed {
                return lhsUsed && !rhsUsed
            }
            if lhsUsed && rhsUsed && lhsCount != rhsCount {
                return lhsCount > rhsCount
            }
            return naturalOrderIndexByID[lhs.id, default: Int.max] < naturalOrderIndexByID[rhs.id, default: Int.max]
        }
    }
}
