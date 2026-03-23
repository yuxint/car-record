import Foundation

extension CoreConfig {
    /// 22 款思域默认项目：顺序用于列表“自然排序”与“恢复默认”顺序。
    static let civic2022DefaultItemDefinitions: [DefaultItemDefinition] = [
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
}
