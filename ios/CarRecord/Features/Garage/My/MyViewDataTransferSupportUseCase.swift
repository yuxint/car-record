import SwiftUI
import SwiftData

extension MyView {
    /// 当前是否存在任一业务数据：用于决定恢复是否需要二次确认。
    var hasAnyBusinessData: Bool {
        !cars.isEmpty || !serviceRecords.isEmpty || !serviceItemOptions.isEmpty
    }

    /// 清空业务数据：用于重置和恢复前准备。
    func syncAppliedCarSelection() {
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 统一弹出备份恢复处理结果，避免各入口文案风格不一致。
    func presentTransferResult(_ message: String) {
        transferResultMessage = message
        isTransferResultAlertPresented = true
    }
    func modelProfileKey(brand: String, modelName: String) -> String {
        "\(brand.trimmingCharacters(in: .whitespacesAndNewlines))|\(modelName.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// 统一读取 App 包内版本号，确保与安装页使用同一构建注入值。
    var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let normalized = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized
    }

}
