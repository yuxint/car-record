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
        let remindByMileage: Bool
        let remindByTime: Bool
        let warningStartPercent: Int
        let dangerStartPercent: Int
    }

    /// 车型配置：默认项目、默认阈值与排序优先级都按车型定义。
    struct ModelConfig {
        let defaultItemDefinitions: [DefaultItemDefinition]
        let preferredKeysWhenNoLog: [String]
        let defaultWarningStartPercent: Int
        let defaultDangerStartPercent: Int

        var defaultOrderByKey: [String: Int] {
            Dictionary(uniqueKeysWithValues: defaultItemDefinitions.enumerated().map { ($1.key, $0) })
        }
    }

    static let fuelCleanerKey = "fuel_cleaner"
    static let engineOilKey = "engine_oil"
    static let acFilterKey = "ac_filter"
    static let airFilterKey = "air_filter"
    static let transmissionOilKey = "transmission_oil"
    static let brakeFluidKey = "brake_fluid"
    static var warningRangeStartPercent: Int { civic2022WarningStartPercent }
    static var warningRangeEndExclusivePercent: Int { civic2022DangerStartPercent }
    static var dangerStartPercent: Int { civic2022DangerStartPercent }

    /// 兜底车型配置：用于无车辆上下文时的默认行为。
    static let fallbackModelConfig = ModelConfig(
        defaultItemDefinitions: civic2022DefaultItemDefinitions,
        preferredKeysWhenNoLog: [
            engineOilKey,
            fuelCleanerKey,
            acFilterKey,
        ],
        defaultWarningStartPercent: civic2022WarningStartPercent,
        defaultDangerStartPercent: civic2022DangerStartPercent
    )

    /// 按车型返回配置。
    static func modelConfig(brand: String?, modelName: String?) -> ModelConfig {
        let normalizedBrand = (brand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModelName = (modelName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch (normalizedBrand, normalizedModelName) {
        case ("本田", "22款思域"):
            return ModelConfig(
                defaultItemDefinitions: civic2022DefaultItemDefinitions,
                preferredKeysWhenNoLog: [engineOilKey, fuelCleanerKey, acFilterKey],
                defaultWarningStartPercent: civic2022WarningStartPercent,
                defaultDangerStartPercent: civic2022DangerStartPercent
            )
        case ("日产", "22款轩逸"):
            return ModelConfig(
                defaultItemDefinitions: sylphy2022DefaultItemDefinitions,
                preferredKeysWhenNoLog: [engineOilKey, acFilterKey, airFilterKey],
                defaultWarningStartPercent: sylphy2022WarningStartPercent,
                defaultDangerStartPercent: sylphy2022DangerStartPercent
            )
        default:
            return fallbackModelConfig
        }
    }

    static func defaultItemDefinitions(brand: String?, modelName: String?) -> [DefaultItemDefinition] {
        modelConfig(brand: brand, modelName: modelName).defaultItemDefinitions
    }
}
