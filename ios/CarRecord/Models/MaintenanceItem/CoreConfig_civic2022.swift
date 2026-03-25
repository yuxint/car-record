import Foundation

extension CoreConfig {
    /// 黄色阈值范围：100（含）-125（不含）；红色阈值：>=125。
    static let civic2022WarningStartPercent = 100
    static let civic2022DangerStartPercent = 125

    /// 22 款思域默认项目：顺序用于列表“自然排序”与“恢复默认”顺序。
    static let civic2022DefaultItemDefinitions: [DefaultItemDefinition] = [
        DefaultItemDefinition(
            key: fuelCleanerKey,
            defaultName: "汽油发动机清洁剂（燃油宝）",
            mileageInterval: 5000,
            monthInterval: nil,
            remindByMileage: true,
            remindByTime: false,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: engineOilKey,
            defaultName: "机油、机滤",
            mileageInterval: 5000,
            monthInterval: 6,
            remindByMileage: true,
            remindByTime: true,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: acFilterKey,
            defaultName: "空调滤芯",
            mileageInterval: 20_000,
            monthInterval: 12,
            remindByMileage: true,
            remindByTime: true,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: airFilterKey,
            defaultName: "空气滤芯",
            mileageInterval: 20_000,
            monthInterval: nil,
            remindByMileage: true,
            remindByTime: false,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: transmissionOilKey,
            defaultName: "变速箱油",
            mileageInterval: 40_000,
            monthInterval: 24,
            remindByMileage: true,
            remindByTime: true,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: brakeFluidKey,
            defaultName: "制动液（刹车油）",
            mileageInterval: nil,
            monthInterval: 36,
            remindByMileage: false,
            remindByTime: true,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: sparkPlugKey,
            defaultName: "火花塞",
            mileageInterval: 100_000,
            monthInterval: nil,
            remindByMileage: true,
            remindByTime: false,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: driveBeltKey,
            defaultName: "检查传动皮带",
            mileageInterval: 40_000,
            monthInterval: 24,
            remindByMileage: true,
            remindByTime: true,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: valveClearanceKey,
            defaultName: "检查气门间隙",
            mileageInterval: 120_000,
            monthInterval: nil,
            remindByMileage: true,
            remindByTime: false,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: brakeKey,
            defaultName: "检查制动器（刹车）",
            mileageInterval: 120_000,
            monthInterval: nil,
            remindByMileage: true,
            remindByTime: false,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: antifreezeKey,
            defaultName: "冷却液（防冻液）",
            mileageInterval: 200_000,
            monthInterval: 120,
            remindByMileage: true,
            remindByTime: true,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: gasFilterKey,
            defaultName: "汽油滤芯",
            mileageInterval: 140_000,
            monthInterval: nil,
            remindByMileage: true,
            remindByTime: false,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
        DefaultItemDefinition(
            key: tireRotationKey,
            defaultName: "轮胎换位",
            mileageInterval: 10_000,
            monthInterval: nil,
            remindByMileage: true,
            remindByTime: false,
            warningStartPercent: civic2022WarningStartPercent,
            dangerStartPercent: civic2022DangerStartPercent
        ),
    ]
}
