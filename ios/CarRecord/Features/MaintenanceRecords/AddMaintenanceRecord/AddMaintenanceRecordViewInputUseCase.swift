import SwiftUI
import SwiftData
import UIKit

extension AddMaintenanceRecordView {
    func loadInitialValuesIfNeeded() {
        guard !hasLoadedInitialValues else { return }
        hasLoadedInitialValues = true

        if let editingRecord {
            selectedCarID = editingRecord.car?.id ?? availableCars.first?.id
            if let lockedItemID {
                selectedItems = [lockedItemID]
            } else {
                selectedItems = Set(CoreConfig.parseItemIDs(editingRecord.itemIDsRaw))
            }
            maintenanceDate = editingRecord.date
            cost = formatCost(editingRecord.cost)
            let segments = MileageSegmentFormatter.segments(from: editingRecord.mileage)
            mileageWan = segments.wan
            mileageQian = segments.qian
            mileageBai = segments.bai
            note = editingRecord.note
            return
        }

        selectedCarID = availableCars.first?.id
        cost = "0"
        applyDefaultMileageIfNeeded(for: selectedCarID)
    }

    /// 切换多选项状态。
    func toggleItem(_ itemID: UUID) {
        guard !isItemSelectionLocked else { return }
        if selectedItems.contains(itemID) {
            selectedItems.remove(itemID)
        } else {
            selectedItems.insert(itemID)
        }
    }

    /// 过滤非法字符并限制 2 位小数。
    func sanitizeCostInput(_ raw: String) -> String {
        let filtered = raw.filter { $0.isNumber || $0 == "." }
        if filtered.isEmpty { return "" }

        var result = ""
        var hasDot = false
        var fractionCount = 0

        for char in filtered {
            if char == "." {
                if hasDot { continue }
                hasDot = true
                if result.isEmpty { result = "0" }
                result.append(char)
                continue
            }

            if hasDot {
                if fractionCount >= 2 { continue }
                fractionCount += 1
            }
            result.append(char)
        }

        return result
    }

    /// 编辑态费用展示：最多两位小数，去掉无效尾零。
    func formatCost(_ value: Double) -> String {
        if value == 0 { return "0" }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }

    /// 新增场景默认里程：取车辆信息中的当前里程，无车辆时为 0。
    func applyDefaultMileageIfNeeded(for carID: UUID?) {
        guard editingRecord == nil else { return }

        guard let carID else {
            mileageWan = 0
            mileageQian = 0
            mileageBai = 0
            return
        }

        let carMileage = availableCars.first(where: { $0.id == carID })?.mileage ?? 0
        let segments = MileageSegmentFormatter.segments(from: carMileage)
        mileageWan = segments.wan
        mileageQian = segments.qian
        mileageBai = segments.bai
    }
    func formattedYearInterval(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    /// 统一拉起弹窗：先收起键盘，避免出现“要点几次才弹出”的交互问题。
    func presentPickerSheet(_ sheet: MaintenancePickerSheet) {
        closeInputEditors()
        DispatchQueue.main.async {
            activePickerSheet = sheet
        }
    }

    /// 统一收起当前输入态：用于弹窗切换和键盘右上角“保存”按钮。
    func closeInputEditors() {
        focusedField = nil
        hideKeyboard()
    }

    /// 主动结束当前输入，避免键盘占位视图约束冲突。
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

}
