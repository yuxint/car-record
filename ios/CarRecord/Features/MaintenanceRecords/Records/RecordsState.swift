import Foundation

/// 展示模式：默认按日期，支持切换按项目。
enum LogDisplayMode: String, CaseIterable, Identifiable {
    case byDate
    case byItem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .byDate:
            return "按周期"
        case .byItem:
            return "按项目"
        }
    }
}

/// 多选弹窗类型：区分“车辆筛选”和“项目筛选”。
enum FilterSelectionKind: String {
    case car
    case item
}

/// 多选弹窗目标：区分当前是哪个展示模式在配置筛选条件。
struct FilterSelectionSheetTarget: Identifiable {
    let mode: LogDisplayMode
    let kind: FilterSelectionKind

    var id: String {
        "\(mode.rawValue)-\(kind.rawValue)"
    }

    var title: String {
        switch kind {
        case .car:
            return "选择车辆"
        case .item:
            return "选择保养项目"
        }
    }
}

/// 多选弹窗通用项模型。
struct FilterSelectionOption: Identifiable {
    let id: UUID
    let name: String
}

/// 记录筛选状态：空集合表示“全选”；按项目模式仅使用项目筛选字段。
struct LogFilterState {
    var selectedCarIDs: Set<UUID> = []
    var selectedItemIDs: Set<UUID> = []
    var selectedYear: Int?
}

/// “按日期”展示时的聚合模型。
struct MaintenanceDateGroup: Identifiable {
    let date: Date
    let records: [MaintenanceRecord]
    let itemSummary: String

    var id: Date { date }

    var totalCost: Double {
        records.reduce(0) { $0 + $1.cost }
    }

}

/// “按项目”展示时的中间行模型。
struct MaintenanceItemRow: Identifiable {
    let id: String
    let itemID: UUID
    let itemName: String
    let record: MaintenanceRecord
}

/// 编辑目标：区分“整单编辑”与“按项目入口编辑”。
struct MaintenanceRecordEditTarget: Identifiable {
    let record: MaintenanceRecord
    let lockedItemID: UUID?

    var id: String {
        "\(record.id.uuidString)-\(lockedItemID?.uuidString ?? "all")"
    }
}
