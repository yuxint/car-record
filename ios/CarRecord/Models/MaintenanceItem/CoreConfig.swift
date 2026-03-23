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

    /// 日产车型默认项目：默认与本田一致，部分车型可按车型覆盖。
    private static let nissanDefaultItemDefinitions: [DefaultItemDefinition] = hondaDefaultItemDefinitions
    private static let sylphy2022DefaultItemDefinitions: [DefaultItemDefinition] = nissanDefaultItemDefinitions.compactMap { definition in
        guard definition.key != fuelCleanerKey else { return nil }
        if definition.key == engineOilKey {
            return DefaultItemDefinition(
                key: definition.key,
                defaultName: definition.defaultName,
                mileageInterval: 10_000,
                monthInterval: definition.monthInterval
            )
        }
        return definition
    }

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
    static let defaultOrderByKey: [String: Int] = Dictionary(
        uniqueKeysWithValues: defaultItemDefinitions.enumerated().map { ($1.key, $0) }
    )

    /// 按车辆品牌返回默认项目定义；后续新增车型只需补充这里的分支。
    static func defaultItemDefinitions(brand: String?, modelName: String?) -> [DefaultItemDefinition] {
        let normalizedBrand = (brand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModelName = (modelName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalizedBrand {
        case "日产":
            switch normalizedModelName {
            case "22款轩逸":
                return sylphy2022DefaultItemDefinitions
            default:
                return nissanDefaultItemDefinitions
            }
        case "本田", "东风本田":
            return hondaDefaultItemDefinitions
        default:
            return hondaDefaultItemDefinitions
        }
    }
}
