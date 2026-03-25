import Foundation

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
        from definition: CoreConfig.DefaultItemDefinition
    ) -> MaintenanceItemDraft {
        let thresholds = CoreConfig.normalizedProgressThresholds(
            warning: definition.warningStartPercent,
            danger: definition.dangerStartPercent
        )
        return MaintenanceItemDraft(
            name: definition.defaultName,
            isDefault: true,
            catalogKey: definition.key,
            isEnabled: true,
            remindByMileage: definition.remindByMileage,
            mileageInterval: definition.mileageInterval ?? 0,
            remindByTime: definition.remindByTime,
            monthInterval: definition.monthInterval ?? 0,
            warningStartPercent: thresholds.warning,
            dangerStartPercent: thresholds.danger
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
}
