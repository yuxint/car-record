import SwiftUI
import SwiftData

extension AddCarView {
    var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian, bai: mileageBai)
    }

    /// 基础表单校验：防止空值和非法里程进入本地数据库。
    var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    func carModelKey(brand: String, modelName: String) -> String {
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(normalizedBrand)|\(normalizedModel)"
    }

    /// 统一拉起弹窗：规避首次进入页面时按钮点击偶发失效的问题。
    func presentPickerSheet(_ sheet: CarPickerSheet) {
        DispatchQueue.main.async {
            activePickerSheet = sheet
        }
    }

}
