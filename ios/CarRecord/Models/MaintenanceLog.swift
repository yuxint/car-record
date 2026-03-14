import Foundation
import SwiftData

/// 保养记录实体：记录项目、费用、里程并绑定所属车辆。
@Model
final class MaintenanceLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var cost: Double
    var mileage: Int
    var note: String
    var car: Car?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        title: String,
        cost: Double,
        mileage: Int,
        note: String = "",
        car: Car
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.cost = cost
        self.mileage = mileage
        self.note = note
        self.car = car
    }
}

/// 保养项目配置：默认项目与自定义项目统一持久化，供新增/编辑/管理页复用。
@Model
final class MaintenanceItemOption {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var isDefault: Bool
    var remindByMileage: Bool
    var mileageInterval: Int
    var remindByTime: Bool
    var monthInterval: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool,
        remindByMileage: Bool = true,
        mileageInterval: Int = 5000,
        remindByTime: Bool = false,
        monthInterval: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.remindByMileage = remindByMileage
        self.mileageInterval = mileageInterval
        self.remindByTime = remindByTime
        self.monthInterval = monthInterval
        self.createdAt = createdAt
    }
}

/// 保养项目工具：默认项维护 + 多选字符串序列化。
enum MaintenanceItemCatalog {
    static let allItems: [String] = [
        "汽油发动机清洁剂",
        "机油（含机滤，放油口垫片）",
        "空调滤芯",
        "空气滤芯",
        "变速箱油",
        "刹车油",
    ]

    /// 默认项目提醒规则（公里/月份）。
    private static let defaultRules: [String: (mileage: Int?, months: Int?)] = [
        "汽油发动机清洁剂": (5000, nil),
        "机油（含机滤，放油口垫片）": (5000, 6),
        "空气滤芯": (20_000, nil),
        "空调滤芯": (20_000, 12),
        "变速箱油": (nil, 24),
        "刹车油": (nil, 36),
    ]

    /// 历史名称兼容：把旧名称统一迁移为新名称，避免列表和记录出现混用。
    private static let legacyNameMap: [String: String] = [
        "燃油宝": "汽油发动机清洁剂"
    ]

    /// 按约定分隔符将多选项目拼接为单个字符串，兼容当前本地数据结构。
    static func join(_ items: [String]) -> String {
        items.joined(separator: "、")
    }

    /// 从已存字符串还原多选项目，便于编辑和“按项目”视图展开。
    static func parse(_ title: String) -> [String] {
        title
            .split(separator: "、")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

        return parts.isEmpty ? "未设置" : parts.joined(separator: " / ")
    }

    /// 暴露默认规则，供“恢复默认值”功能复用。
    static func defaultRule(for item: String) -> (mileage: Int?, months: Int?) {
        defaultRules[item] ?? (nil, nil)
    }

    /// 迁移历史项目名称，并同步更新已存在的保养记录标题。
    static func normalizeLegacyNames(in modelContext: ModelContext) {
        do {
            let options = try modelContext.fetch(FetchDescriptor<MaintenanceItemOption>())
            let logs = try modelContext.fetch(FetchDescriptor<MaintenanceLog>())

            var optionsByName: [String: MaintenanceItemOption] = [:]
            for option in options {
                optionsByName[option.name] = option
            }

            var needsSave = false
            for (oldName, newName) in legacyNameMap {
                guard let oldOption = optionsByName[oldName] else { continue }

                if let newOption = optionsByName[newName], newOption.id != oldOption.id {
                    if oldOption.isDefault, newOption.isDefault == false {
                        newOption.isDefault = true
                        needsSave = true
                    }
                    modelContext.delete(oldOption)
                    needsSave = true
                } else {
                    oldOption.name = newName
                    optionsByName[newName] = oldOption
                    optionsByName.removeValue(forKey: oldName)
                    needsSave = true
                }

                for log in logs {
                    let items = parse(log.title)
                    let renamed = items.map { $0 == oldName ? newName : $0 }
                    if renamed != items {
                        log.title = join(renamed)
                        needsSave = true
                    }
                }
            }

            if needsSave {
                try modelContext.save()
            }
        } catch {
            print("迁移历史保养项目名称失败：\(error)")
        }
    }

    /// 初始化默认保养项目，避免首次进入页面为空。
    static func ensureDefaults(in modelContext: ModelContext) {
        do {
            normalizeLegacyNames(in: modelContext)

            let existingOptions = try modelContext.fetch(FetchDescriptor<MaintenanceItemOption>())
            let hasDefaultItems = existingOptions.contains(where: { $0.isDefault })
            guard hasDefaultItems == false else { return }

            var needsSave = false
            for item in allItems {
                let rule = defaultRule(for: item)
                let remindByMileage = rule.mileage != nil
                let remindByTime = rule.months != nil
                let mileageInterval = rule.mileage ?? 0
                let monthInterval = rule.months ?? 0

                if let existing = existingOptions.first(where: { $0.name == item }) {
                    existing.isDefault = true
                    existing.remindByMileage = remindByMileage
                    existing.mileageInterval = mileageInterval
                    existing.remindByTime = remindByTime
                    existing.monthInterval = monthInterval
                    needsSave = true
                } else {
                    modelContext.insert(
                        MaintenanceItemOption(
                            name: item,
                            isDefault: true,
                            remindByMileage: remindByMileage,
                            mileageInterval: mileageInterval,
                            remindByTime: remindByTime,
                            monthInterval: monthInterval
                        )
                    )
                    needsSave = true
                }
            }

            if needsSave {
                try modelContext.save()
            }
        } catch {
            print("初始化默认保养项目失败：\(error)")
        }
    }
}
