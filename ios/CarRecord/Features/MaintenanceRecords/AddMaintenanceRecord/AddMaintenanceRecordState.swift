import Foundation

enum MaintenancePickerSheet: Identifiable {
    case serviceDate
    case mileage
    case serviceItems

    var id: String {
        switch self {
        case .serviceDate:
            return "serviceDate"
        case .mileage:
            return "mileage"
        case .serviceItems:
            return "serviceItems"
        }
    }
}

/// 输入焦点：用于区分当前是“总费用”还是“备注”在编辑。
enum FocusField {
    case cost
    case note
}

/// 保存后间隔确认草稿：用于回写保养项目的全局默认提醒间隔。
struct MaintenanceIntervalDraft: Identifiable {
    let id: UUID
    let name: String
    let remindByMileage: Bool
    var mileageInterval: Int
    let remindByTime: Bool
    var yearInterval: Double
}
