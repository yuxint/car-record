import Foundation

extension CoreConfig {
    static let sylphy2022WarningStartPercent = 100
    static let sylphy2022DangerStartPercent = 125

    /// 22 款轩逸默认项目：与其他车型独立维护，不做派生引用。
    static let sylphy2022DefaultItemDefinitions: [DefaultItemDefinition] = [
        DefaultItemDefinition(
            key: engineOilKey,
            defaultName: "机油",
            mileageInterval: 10_000,
            monthInterval: 6,
            remindByMileage: true,
            remindByTime: true,
            warningStartPercent: sylphy2022WarningStartPercent,
            dangerStartPercent: sylphy2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: acFilterKey,
            defaultName: "空调滤芯",
            mileageInterval: 20_000,
            monthInterval: 12,
            remindByMileage: true,
            remindByTime: true,
            warningStartPercent: sylphy2022WarningStartPercent,
            dangerStartPercent: sylphy2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: airFilterKey,
            defaultName: "空气滤芯",
            mileageInterval: 20_000,
            monthInterval: nil,
            remindByMileage: true,
            remindByTime: false,
            warningStartPercent: sylphy2022WarningStartPercent,
            dangerStartPercent: sylphy2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: transmissionOilKey,
            defaultName: "变速箱油",
            mileageInterval: nil,
            monthInterval: 24,
            remindByMileage: false,
            remindByTime: true,
            warningStartPercent: sylphy2022WarningStartPercent,
            dangerStartPercent: sylphy2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: brakeFluidKey,
            defaultName: "刹车油",
            mileageInterval: nil,
            monthInterval: 36,
            remindByMileage: false,
            remindByTime: true,
            warningStartPercent: sylphy2022WarningStartPercent,
            dangerStartPercent: sylphy2022DangerStartPercent
        ),
    ]
}
