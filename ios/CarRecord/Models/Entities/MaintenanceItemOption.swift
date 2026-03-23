import Foundation
import SwiftData

/// 保养项目配置：默认项目与自定义项目统一持久化，供新增/编辑/管理页复用。
@Model
final class MaintenanceItemOption {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 项目归属车辆ID：所有项目（默认/自定义）都按车辆隔离。
    var ownerCarID: UUID?
    var isDefault: Bool
    /// 默认项目固定键：用于默认规则映射，避免改名后逻辑失效。
    var catalogKey: String?
    var remindByMileage: Bool
    var mileageInterval: Int
    var remindByTime: Bool
    var monthInterval: Int
    /// 进度颜色阈值：达到黄色阈值进入黄色，超过红色阈值进入红色。
    var warningStartPercent: Int
    var dangerStartPercent: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        ownerCarID: UUID? = nil,
        isDefault: Bool,
        catalogKey: String? = nil,
        remindByMileage: Bool = true,
        mileageInterval: Int = 5000,
        remindByTime: Bool = false,
        monthInterval: Int = 0,
        warningStartPercent: Int = CoreConfig.fallbackModelConfig.defaultWarningStartPercent,
        dangerStartPercent: Int = CoreConfig.fallbackModelConfig.defaultDangerStartPercent,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ownerCarID = ownerCarID
        self.isDefault = isDefault
        self.catalogKey = catalogKey
        self.remindByMileage = remindByMileage
        self.mileageInterval = mileageInterval
        self.remindByTime = remindByTime
        self.monthInterval = monthInterval
        let normalizedThresholds = CoreConfig.normalizedProgressThresholds(
            warning: warningStartPercent,
            danger: dangerStartPercent
        )
        self.warningStartPercent = normalizedThresholds.warning
        self.dangerStartPercent = normalizedThresholds.danger
        self.createdAt = createdAt
    }
}
