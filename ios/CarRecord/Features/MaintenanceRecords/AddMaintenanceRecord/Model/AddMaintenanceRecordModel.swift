import Foundation

/// 保存后间隔确认草稿：用于回写保养项目的全局默认提醒间隔。
struct MaintenanceIntervalDraft: Identifiable {
    let id: UUID
    let name: String
    let remindByMileage: Bool
    var mileageInterval: Int
    let remindByTime: Bool
    var yearInterval: Double
}

/// 编辑态草稿快照：用于判断是否有实际改动。
struct MaintenanceEditDraftSnapshot: Equatable {
    let selectedCarID: UUID?
    let selectedItems: Set<UUID>
    let maintenanceDate: Date
    let mileage: Int
    let cost: Double
    let note: String
}
