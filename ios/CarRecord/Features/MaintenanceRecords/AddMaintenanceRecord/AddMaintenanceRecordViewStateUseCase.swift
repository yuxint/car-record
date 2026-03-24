import SwiftUI
import SwiftData
import UIKit

extension AddMaintenanceRecordView {
    var selectedCar: Car? {
        guard let selectedCarID else { return nil }
        return availableCars.first(where: { $0.id == selectedCarID })
    }

    var selectedCarDisplayText: String {
        guard let selectedCar else { return "未选择" }
        return "\(CarDisplayFormatter.name(selectedCar))（\(AppDateContext.formatShortDate(selectedCar.purchaseDate))）"
    }

    var scopedServiceItemOptions: [MaintenanceItemOption] {
        CoreConfig.scopedOptions(serviceItemOptions, carID: selectedCarID)
    }

    /// 合并“万 + 千 + 百”三段，得到保养发生时的公里数。
    var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian, bai: mileageBai)
    }

    /// 可选项目列表：先按车辆禁用状态过滤，再按统一规则排序。
    var availableItemOptions: [MaintenanceItemOption] {
        let visibleOptions = CoreConfig.filterDisabledOptions(
            scopedServiceItemOptions,
            disabledItemIDsRaw: selectedCar?.disabledItemIDsRaw ?? "",
            includeDisabled: editingRecord != nil
        )
        return CoreConfig.sortedOptions(
            visibleOptions,
            brand: selectedCar?.brand,
            modelName: selectedCar?.modelName
        )
    }
    var selectedItemsText: String {
        selectedItems.isEmpty ? "请选择" : "已选\(selectedItems.count)项"
    }

    /// 按项目入口锁定编辑时，展示当前锁定项目名称。
    var lockedItemNameText: String {
        guard let lockedItemID else { return selectedItemsText }
        let names = CoreConfig.itemNames(from: [lockedItemID], options: scopedServiceItemOptions)
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
            guard scopedServiceItemOptions.contains(where: { $0.id == lockedItemID }) else { return false }
        }
        if isCostReadOnly { return true }
        return parsedCost != nil
    }

    /// 编辑场景下，只有草稿发生变更才允许保存。
    var canSubmit: Bool {
        guard canSave else { return false }
        guard editingRecord != nil else { return true }
        return hasDraftChanges
    }

    var hasDraftChanges: Bool {
        guard let initialEditDraftSnapshot else { return false }
        return initialEditDraftSnapshot != currentEditDraftSnapshot
    }

    var currentEditDraftSnapshot: MaintenanceEditDraftSnapshot {
        let normalizedDate = Calendar.current.startOfDay(for: maintenanceDate)
        return MaintenanceEditDraftSnapshot(
            selectedCarID: selectedCarID,
            selectedItems: selectedItems,
            maintenanceDate: normalizedDate,
            mileage: currentMileage,
            cost: parsedCost ?? editingRecord?.cost ?? 0,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
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

    func captureInitialEditDraftSnapshotIfNeeded() {
        guard editingRecord != nil else { return }
        guard initialEditDraftSnapshot == nil else { return }
        initialEditDraftSnapshot = currentEditDraftSnapshot
    }

}
