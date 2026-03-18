import Foundation
import SwiftData

/// 周期-项目关系实体：用于数据库层硬约束“同车同日同项目唯一”。
@Model
final class MaintenanceRecordItem {
    @Attribute(.unique) var id: UUID
    /// 唯一键：`cycleKey + itemID`。
    @Attribute(.unique) var cycleItemKey: String?
    var itemID: UUID
    var createdAt: Date
    var record: MaintenanceRecord?

    init(
        id: UUID = UUID(),
        cycleItemKey: String,
        itemID: UUID,
        createdAt: Date = Date(),
        record: MaintenanceRecord
    ) {
        self.id = id
        self.cycleItemKey = cycleItemKey
        self.itemID = itemID
        self.createdAt = createdAt
        self.record = record
    }

    /// 生成“周期+项目”唯一键。
    static func cycleItemKey(cycleKey: String, itemID: UUID) -> String {
        "\(cycleKey)|\(itemID.uuidString)"
    }
}
