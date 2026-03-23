import Foundation

enum CarPickerSheet: Identifiable {
    case mileage
    case onRoadDate

    var id: String {
        switch self {
        case .mileage:
            return "mileage"
        case .onRoadDate:
            return "onRoadDate"
        }
    }
}

/// 保养项目设置页面路由：区分“编辑项目”与“新增自定义项目”。
enum MaintenanceDraftSheetTarget: Identifiable, Hashable {
    case edit(UUID)
    case addCustom
    case editExisting(UUID)

    var id: String {
        switch self {
        case .edit(let id):
            return "edit-\(id.uuidString)"
        case .addCustom:
            return "add-custom"
        case .editExisting(let id):
            return "edit-existing-\(id.uuidString)"
        }
    }
}

/// 添加车辆页的保养项目草稿模型：承载首次设置时的全部可编辑配置。
struct MaintenanceItemDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var isDefault: Bool
    var catalogKey: String?
    var isEnabled: Bool
    var remindByMileage: Bool
    var mileageInterval: Int
    var remindByTime: Bool
    var monthInterval: Int
    var warningStartPercent: Int
    var dangerStartPercent: Int

    static func defaultDraft(
        from definition: CoreConfig.DefaultItemDefinition,
        warningStartPercent: Int,
        dangerStartPercent: Int
    ) -> MaintenanceItemDraft {
        MaintenanceItemDraft(
            name: definition.defaultName,
            isDefault: true,
            catalogKey: definition.key,
            isEnabled: true,
            remindByMileage: definition.mileageInterval != nil,
            mileageInterval: definition.mileageInterval ?? 0,
            remindByTime: definition.monthInterval != nil,
            monthInterval: definition.monthInterval ?? 0,
            warningStartPercent: warningStartPercent,
            dangerStartPercent: dangerStartPercent
        )
    }

    static func defaultDraft(
        name: String,
        warningStartPercent: Int,
        dangerStartPercent: Int
    ) -> MaintenanceItemDraft {
        MaintenanceItemDraft(
            name: name,
            isDefault: false,
            catalogKey: nil,
            isEnabled: true,
            remindByMileage: true,
            mileageInterval: 5000,
            remindByTime: false,
            monthInterval: 0,
            warningStartPercent: warningStartPercent,
            dangerStartPercent: dangerStartPercent
        )
    }

    static func reminderSummary(for draft: MaintenanceItemDraft) -> String {
        var parts: [String] = []
        if draft.remindByMileage {
            parts.append("\(max(1, draft.mileageInterval)) km")
        }
        if draft.remindByTime {
            let years = Double(max(1, draft.monthInterval)) / 12.0
            let yearText: String
            if years.truncatingRemainder(dividingBy: 1) == 0 {
                yearText = "\(Int(years))年"
            } else {
                yearText = "\(String(format: "%.1f", years))年"
            }
            parts.append(yearText)
        }
        if parts.isEmpty {
            parts.append("未设置")
        }
        return "\(parts.joined(separator: " / ")) · 阈值\(draft.warningStartPercent)%/\(draft.dangerStartPercent)%"
    }
}
