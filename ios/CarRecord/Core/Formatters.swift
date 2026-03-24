import Foundation

/// 统一货币格式化，避免各页面重复创建 NumberFormatter。
enum CurrencyFormatter {
    static func value(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}

/// 里程分段工具：统一“万 + 千”两段选择与整数公里之间的转换。
enum MileageSegmentFormatter {
    static func mileage(wan: Int, qian: Int, bai: Int) -> Int {
        (wan * 10_000) + (qian * 1_000) + (bai * 100)
    }

    static func segments(from mileage: Int) -> (wan: Int, qian: Int, bai: Int) {
        let safeMileage = max(0, mileage)
        let wan = min(max(safeMileage / 10_000, 0), 99)
        let qian = min(max((safeMileage % 10_000) / 1_000, 0), 9)
        let bai = min(max((safeMileage % 1_000) / 100, 0), 9)
        return (wan, qian, bai)
    }

    /// 统一里程三段文案，避免页面各自拼接造成展示不一致。
    static func text(wan: Int, qian: Int, bai: Int) -> String {
        "\(wan)万 \(qian)千 \(bai)百"
    }
}

/// 车龄格式化：按年计算并保留 1 位小数，避免手动维护车龄字段。
enum CarAgeFormatter {
    static func yearsText(from date: Date, now: Date = AppDateContext.now()) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        let years = interval / (365.25 * 24 * 60 * 60)
        return String(format: "%.1f", years)
    }
}

/// 车辆文案格式化：统一“品牌 + 车型”展示。
enum CarDisplayFormatter {
    static func name(_ car: Car) -> String {
        return "\(car.brand) \(car.modelName)"
    }
}

/// 统一弹窗按钮文案，避免页面散落硬编码。
enum AppPopupText {
    static let cancel = "取消"
    static let confirm = "确认"
    static let done = "完成"
    static let acknowledge = "我知道了"
    static let goEdit = "去编辑"
}

/// 统一弹窗标题与提示文案，便于集中维护。
enum AppAlertText {
    static let promptTitle = "提示"
    static let saveFailedTitle = "保存失败"
    static let operationFailedTitle = "操作失败"
    static let duplicateCycleTitle = "已存在同日记录"
    static let resetDataConfirmTitle = "确认重置数据？"
    static let restoreDataConfirmTitle = "确认恢复数据？"
    static let deleteCarConfirmTitle = "确认删除车辆？"
    static let transferResultTitle = "备份恢复结果"

    static let confirmResetAction = "确认重置"
    static let confirmRestoreAction = "确认恢复"
    static let confirmDeleteAction = "确认删除"

    static let resetDataMessage = "将清空车辆、保养记录和全部保养项目，且无法恢复。"
    static let restoreDataMessage = "恢复会先清空当前全部数据，再导入备份文件。"
    static let deleteCarFallbackMessage = "将删除该车辆及其关联的保养记录、保养项目设置等全部数据，且无法恢复。"

    static func deleteCarMessage(carName: String) -> String {
        "将删除“\(carName)”及其关联的保养记录、保养项目设置等全部数据，且无法恢复。"
    }
}
