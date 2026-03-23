import SwiftUI
import SwiftData
import UIKit

extension AddMaintenanceRecordView {
    /// 合并“万 + 千 + 百”三段，得到保养发生时的公里数。
    var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian, bai: mileageBai)
    }

    /// 可选项目列表排序规则：
    /// 1) 无保养记录时：机油/汽油发动机清洁剂/空调滤芯优先，其余按自然顺序。
    /// 2) 有保养记录时：按项目被保养次数倒序，未保养项目按自然顺序。
    var availableItemOptions: [MaintenanceItemOption] {
        let visibleOptions: [MaintenanceItemOption]
        if editingRecord == nil {
            let disabledItemIDs: Set<UUID>
            if let selectedCarID,
               let selectedCar = availableCars.first(where: { $0.id == selectedCarID }) {
                disabledItemIDs = Set(CoreConfig.parseItemIDs(selectedCar.disabledItemIDsRaw))
            } else {
                disabledItemIDs = []
            }
            visibleOptions = serviceItemOptions.filter { disabledItemIDs.contains($0.id) == false }
        } else {
            visibleOptions = serviceItemOptions
        }
        return CoreConfig.sortedSelectionOptions(
            options: visibleOptions,
            records: serviceRecords
        )
    }
    var selectedItemsText: String {
        selectedItems.isEmpty ? "请选择" : "已选\(selectedItems.count)项"
    }

    /// 按项目入口锁定编辑时，展示当前锁定项目名称。
    var lockedItemNameText: String {
        guard let lockedItemID else { return selectedItemsText }
        let names = CoreConfig.itemNames(from: [lockedItemID], options: serviceItemOptions)
        return names.first ?? ""
    }

    /// 按项目入口编辑时，保养项目固定为当前项目。
    var isItemSelectionLocked: Bool {
        editingRecord != nil && lockedItemID != nil
    }

    /// 按项目入口编辑时，总费用为整单字段，设为只读避免误改。
    var isCostReadOnly: Bool {
        editingRecord != nil && lockedItemID != nil && !isSplitEditMode
    }

    /// 按项目编辑且跨周期时会拆单；拆单时允许填写新单费用和备注。
    var isSplitEditMode: Bool {
        guard let editingRecord, let lockedItemID else { return false }
        let originalItemIDs = CoreConfig.parseItemIDs(editingRecord.itemIDsRaw)
        guard originalItemIDs.contains(lockedItemID), originalItemIDs.count > 1 else { return false }
        guard let selectedCarID, let selectedCar = availableCars.first(where: { $0.id == selectedCarID }) else { return false }
        let targetCycleKey = MaintenanceRecord.cycleKey(carID: selectedCar.id, date: maintenanceDate)
        return editingRecord.cycleKey != targetCycleKey
    }

    /// 合法费用：非负，最多 2 位小数。
    var parsedCost: Double? {
        guard !cost.isEmpty, let value = Double(cost), value >= 0 else { return nil }
        return value
    }

    /// 基础输入校验，避免非法数据入库。
    var canSave: Bool {
        guard selectedCarID != nil, !selectedItems.isEmpty else { return false }
        if let lockedItemID, isItemSelectionLocked {
            guard serviceItemOptions.contains(where: { $0.id == lockedItemID }) else { return false }
        }
        if isCostReadOnly { return true }
        return parsedCost != nil
    }

    /// 当前是否处于任意输入态：用于避免导航栏“保存”与键盘操作冲突。
    var isAnyInputActive: Bool {
        focusedField != nil
    }
    var availableCars: [Car] {
        guard limitToAppliedCar else { return cars }
        guard let appliedCarID = AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars) else {
            return []
        }
        return cars.filter { $0.id == appliedCarID }
    }

    /// 仅在隔离模式下修正持久化车型ID，避免引用已删除车辆。
    func syncAppliedCarSelectionIfNeeded() {
        guard limitToAppliedCar else { return }
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 确保当前表单选中车辆始终落在可用范围内。
    func ensureSelectedCarIsValid() {
        guard availableCars.contains(where: { $0.id == selectedCarID }) == false else { return }
        selectedCarID = availableCars.first?.id
    }

}
