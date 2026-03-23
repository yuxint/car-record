import Foundation

/// 保养项目工具：默认项维护 + 多选字符串序列化。
enum CoreConfig {
    static let itemIDSeparator = "|"

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

    /// 兜底默认项：用于没有车辆上下文或品牌未覆盖时的默认行为。
    static let defaultItemDefinitions: [DefaultItemDefinition] = civic2022DefaultItemDefinitions

    static let preferredKeysWhenNoLog: [String] = [
        engineOilKey,
        fuelCleanerKey,
        acFilterKey,
    ]

    /// 默认进度颜色阈值：100% 开始黄色，超过 125% 进入红色。
    static let defaultWarningStartPercent = 100
    static let defaultDangerStartPercent = 125

    /// 默认项目顺序索引：用于稳定排序（默认项在前，且按配置顺序）。
    static let defaultOrderByKey: [String: Int] = Dictionary(
        uniqueKeysWithValues: defaultItemDefinitions.enumerated().map { ($1.key, $0) }
    )

    /// 按车型返回默认项目定义；品牌信息不参与默认配置选择。
    static func defaultItemDefinitions(brand: String?, modelName: String?) -> [DefaultItemDefinition] {
        _ = brand
        let normalizedModelName = (modelName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalizedModelName {
        case "22款思域":
            return civic2022DefaultItemDefinitions
        case "22款轩逸":
            return sylphy2022DefaultItemDefinitions
        default:
            return civic2022DefaultItemDefinitions
        }
    }
}
