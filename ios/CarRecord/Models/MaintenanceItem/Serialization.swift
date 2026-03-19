import Foundation

extension CoreConfig {
    /// 将项目ID列表拼接为持久化字符串。
    static func joinItemIDs(_ itemIDs: [UUID]) -> String {
        itemIDs.map(\.uuidString).joined(separator: itemIDSeparator)
    }

    /// 从持久化字符串还原项目ID列表。
    static func parseItemIDs(_ raw: String) -> [UUID] {
        raw
            .split(separator: Character(itemIDSeparator))
            .compactMap { UUID(uuidString: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    /// 根据项目ID列表映射展示名称；不存在的ID会被忽略。
    static func itemNames(from itemIDs: [UUID], options: [MaintenanceItemOption]) -> [String] {
        guard !itemIDs.isEmpty else { return [] }

        let optionNameByID = Dictionary(uniqueKeysWithValues: options.map { ($0.id, $0.name) })
        return itemIDs.compactMap { optionNameByID[$0] }
    }

    /// 由持久化字符串映射项目展示名称。
    static func itemNames(from itemIDsRaw: String, options: [MaintenanceItemOption]) -> [String] {
        itemNames(from: parseItemIDs(itemIDsRaw), options: options)
    }

    /// 判断日志是否包含指定项目ID。
    static func contains(itemID: UUID, in raw: String) -> Bool {
        parseItemIDs(raw).contains(itemID)
    }
}
