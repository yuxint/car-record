import Foundation
import SwiftData

/// 保养记录实体：记录项目、费用、里程并绑定所属车辆。
@Model
final class MaintenanceRecord {
    @Attribute(.unique) var id: UUID
    /// 周期唯一键：`carID + yyyy-MM-dd`，用于数据库层约束“同车同日唯一”。
    @Attribute(.unique) var cycleKey: String?
    /// 周期项目关系：用于数据库层约束“同车同日同项目唯一”。
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRecordItem.record) var itemRelations: [MaintenanceRecordItem]
    var date: Date
    /// 保养项目ID列表（字符串持久化）：通过ID映射名称，避免改名影响引用。
    var itemIDsRaw: String
    var cost: Double
    var mileage: Int
    var note: String
    var car: Car?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        itemIDsRaw: String,
        cost: Double,
        mileage: Int,
        note: String = "",
        car: Car
    ) {
        self.id = id
        self.cycleKey = Self.cycleKey(carID: car.id, date: date)
        self.itemRelations = []
        self.date = date
        self.itemIDsRaw = itemIDsRaw
        self.cost = cost
        self.mileage = mileage
        self.note = note
        self.car = car
    }

    /// 生成“同车同日”唯一键，日期统一按 yyyy-MM-dd 落键。
    static func cycleKey(carID: UUID, date: Date) -> String {
        let formatter = AppDateContext.makeDisplayFormatter("yyyy-MM-dd")
        let day = formatter.string(from: Calendar.current.startOfDay(for: date))
        return "\(carID.uuidString)|\(day)"
    }
}

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

/// 保养项目配置：默认项目与自定义项目统一持久化，供新增/编辑/管理页复用。
@Model
final class MaintenanceItemOption {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
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
        isDefault: Bool,
        catalogKey: String? = nil,
        remindByMileage: Bool = true,
        mileageInterval: Int = 5000,
        remindByTime: Bool = false,
        monthInterval: Int = 0,
        warningStartPercent: Int = MaintenanceItemCatalog.defaultWarningStartPercent,
        dangerStartPercent: Int = MaintenanceItemCatalog.defaultDangerStartPercent,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.catalogKey = catalogKey
        self.remindByMileage = remindByMileage
        self.mileageInterval = mileageInterval
        self.remindByTime = remindByTime
        self.monthInterval = monthInterval
        let normalizedThresholds = MaintenanceItemCatalog.normalizedProgressThresholds(
            warning: warningStartPercent,
            danger: dangerStartPercent
        )
        self.warningStartPercent = normalizedThresholds.warning
        self.dangerStartPercent = normalizedThresholds.danger
        self.createdAt = createdAt
    }
}

/// 保养项目工具：默认项维护 + 多选字符串序列化。
enum MaintenanceItemCatalog {
    private static let itemIDSeparator = "|"

    /// 默认项目定义：通过固定 `key` 映射规则，避免依赖名称字符串。
    struct DefaultItemDefinition {
        let key: String
        let defaultName: String
        let mileageInterval: Int?
        let monthInterval: Int?
    }

    static let fuelCleanerKey = "fuel_cleaner"
    static let engineOilKey = "engine_oil"
    static let acFilterKey = "ac_filter"
    static let airFilterKey = "air_filter"
    static let transmissionOilKey = "transmission_oil"
    static let brakeFluidKey = "brake_fluid"

    /// 本田车型默认项目：顺序用于列表“自然排序”与“恢复默认”顺序。
    private static let hondaDefaultItemDefinitions: [DefaultItemDefinition] = [
        DefaultItemDefinition(
            key: fuelCleanerKey,
            defaultName: "汽油发动机清洁剂",
            mileageInterval: 5000,
            monthInterval: nil
        ),
        DefaultItemDefinition(
            key: engineOilKey,
            defaultName: "机油",
            mileageInterval: 5000,
            monthInterval: 6
        ),
        DefaultItemDefinition(
            key: acFilterKey,
            defaultName: "空调滤芯",
            mileageInterval: 20_000,
            monthInterval: 12
        ),
        DefaultItemDefinition(
            key: airFilterKey,
            defaultName: "空气滤芯",
            mileageInterval: 20_000,
            monthInterval: nil
        ),
        DefaultItemDefinition(
            key: transmissionOilKey,
            defaultName: "变速箱油",
            mileageInterval: nil,
            monthInterval: 24
        ),
        DefaultItemDefinition(
            key: brakeFluidKey,
            defaultName: "刹车油",
            mileageInterval: nil,
            monthInterval: 36
        ),
    ]

    /// 日产车型默认项目：当前与本田保持一致，后续可独立维护。
    private static let nissanDefaultItemDefinitions: [DefaultItemDefinition] = hondaDefaultItemDefinitions

    /// 兜底默认项：用于没有车辆上下文或品牌未覆盖时的默认行为。
    static let defaultItemDefinitions: [DefaultItemDefinition] = hondaDefaultItemDefinitions

    static let preferredKeysWhenNoLog: [String] = [
        engineOilKey,
        fuelCleanerKey,
        acFilterKey,
    ]

    /// 默认进度颜色阈值：100% 开始黄色，超过 125% 进入红色。
    static let defaultWarningStartPercent = 100
    static let defaultDangerStartPercent = 125

    /// 默认项目顺序索引：用于稳定排序（默认项在前，且按配置顺序）。
    private static let defaultOrderByKey: [String: Int] = Dictionary(
        uniqueKeysWithValues: defaultItemDefinitions.enumerated().map { ($1.key, $0) }
    )

    /// 按车辆品牌返回默认项目定义；后续新增车型只需补充这里的分支。
    static func defaultItemDefinitions(brand: String?, modelName: String?) -> [DefaultItemDefinition] {
        let normalizedBrand = (brand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let _ = (modelName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalizedBrand {
        case "日产":
            return nissanDefaultItemDefinitions
        case "东风本田":
            return hondaDefaultItemDefinitions
        default:
            return hondaDefaultItemDefinitions
        }
    }

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

    /// 生成提醒规则文本，用于列表摘要展示。
    static func reminderSummary(for option: MaintenanceItemOption) -> String {
        var parts: [String] = []

        if option.remindByMileage, option.mileageInterval > 0 {
            parts.append("\(option.mileageInterval) km")
        }

        if option.remindByTime, option.monthInterval > 0 {
            let years = Double(option.monthInterval) / 12.0
            if years.truncatingRemainder(dividingBy: 1) == 0 {
                parts.append("\(Int(years))年")
            } else {
                parts.append("\(String(format: "%.1f", years))年")
            }
        }

        let reminderText = parts.isEmpty ? "未设置" : parts.joined(separator: " / ")
        let thresholds = normalizedProgressThresholds(
            warning: option.warningStartPercent,
            danger: option.dangerStartPercent
        )
        return "\(reminderText) · 阈值\(thresholds.warning)%/\(thresholds.danger)%"
    }

    /// 统一校正颜色阈值，保证“黄色阈值 < 红色阈值”。
    static func normalizedProgressThresholds(warning: Int, danger: Int) -> (warning: Int, danger: Int) {
        let safeWarning = max(1, warning)
        let safeDanger = max(safeWarning + 1, danger)
        return (safeWarning, safeDanger)
    }

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
