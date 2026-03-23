import Foundation

extension CoreConfig {
    /// 22 款轩逸默认项目：与其他车型独立维护，不做派生引用。
    static let sylphy2022DefaultItemDefinitions: [DefaultItemDefinition] = [
        DefaultItemDefinition(
            key: engineOilKey,
            defaultName: "机油",
            mileageInterval: 10_000,
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
}
