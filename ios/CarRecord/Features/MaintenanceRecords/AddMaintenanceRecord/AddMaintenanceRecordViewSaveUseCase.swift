import SwiftUI
import SwiftData
import UIKit

extension AddMaintenanceRecordView {
    /// 新增场景进入“确认下次间隔”步骤，不在此时落库。
    func proceedToIntervalConfirmation() {
        closeInputEditors()
        prepareIntervalConfirmationDrafts(for: orderedSelectedItemIDs)
        isIntervalConfirmPresented = true
    }

    /// 根据选择的车辆写入保养记录；新增场景在确认页保存时才真正落库。
    func saveRecord(applyIntervalChanges: Bool = false) {
        guard
            let selectedCarID,
            let selectedCar = availableCars.first(where: { $0.id == selectedCarID })
        else {
            return
        }
        if !isCostReadOnly, parsedCost == nil {
            return
        }
        let finalCost = parsedCost ?? editingRecord?.cost ?? 0
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetCycleKey = MaintenanceRecord.cycleKey(carID: selectedCar.id, date: maintenanceDate)
        let existingCycleRecord = serviceRecords.first { record in
            guard record.id != editingRecord?.id else { return false }
            guard let carID = record.car?.id else { return false }
            return MaintenanceRecord.cycleKey(carID: carID, date: record.date) == targetCycleKey
        }

        if let editingRecord {
            let recordBefore = AppDatabaseSnapshot.maintenanceRecord(editingRecord)
            if let existingCycleRecord {
                duplicateCycleAlertMessage = "“\(AppDateContext.formatShortDate(existingCycleRecord.date))”已存在保养记录，请到保养页编辑该日期记录。"
                if applyIntervalChanges {
                    isIntervalConfirmDuplicateCycleAlertPresented = true
                } else {
                    isDuplicateCycleAlertPresented = true
                }
                return
            }
            if let lockedItemID, isItemSelectionLocked {
                guard applyLockedItemEdit(
                    editingRecord: editingRecord,
                    lockedItemID: lockedItemID,
                    selectedCar: selectedCar,
                    splitCost: finalCost,
                    splitNote: normalizedNote
                ) else {
                    return
                }
            } else {
                let itemIDsRaw = CoreConfig.joinItemIDs(orderedSelectedItemIDs)
                editingRecord.date = maintenanceDate
                editingRecord.itemIDsRaw = itemIDsRaw
                editingRecord.cost = finalCost
                editingRecord.mileage = currentMileage
                editingRecord.note = normalizedNote
                editingRecord.car = selectedCar
                editingRecord.cycleKey = targetCycleKey
                CoreConfig.syncCycleAndRelations(for: editingRecord, in: modelContext)
            }
            AppDatabaseAuditLogger.logUpdate(
                entity: "MaintenanceRecord",
                before: recordBefore,
                after: AppDatabaseSnapshot.maintenanceRecord(editingRecord)
            )
        } else {
            if let existingCycleRecord {
                duplicateCycleAlertMessage = "“\(AppDateContext.formatShortDate(existingCycleRecord.date))”已存在保养记录，请到记录页编辑该日期记录。"
                if applyIntervalChanges {
                    isIntervalConfirmDuplicateCycleAlertPresented = true
                } else {
                    isDuplicateCycleAlertPresented = true
                }
            } else {
                let itemIDsRaw = CoreConfig.joinItemIDs(orderedSelectedItemIDs)
                let record = MaintenanceRecord(
                    date: maintenanceDate,
                    itemIDsRaw: itemIDsRaw,
                    cost: finalCost,
                    mileage: currentMileage,
                    note: normalizedNote,
                    car: selectedCar
                )
                modelContext.insertWithAudit(record)
                CoreConfig.syncCycleAndRelations(for: record, in: modelContext)
            }
            if isDuplicateCycleAlertPresented || isIntervalConfirmDuplicateCycleAlertPresented {
                return
            }
        }

        if applyIntervalChanges {
            applyIntervalConfirmationToOptions()
        }

        /// 保存保养记录后，车辆当前里程与表单里程取较大值，避免里程回退。
        if currentMileage > selectedCar.mileage {
            let carBefore = AppDatabaseSnapshot.car(selectedCar)
            selectedCar.mileage = currentMileage
            AppDatabaseAuditLogger.logUpdate(
                entity: "Car",
                before: carBefore,
                after: AppDatabaseSnapshot.car(selectedCar)
            )
        }

        if let message = modelContext.saveOrLog("保存保养记录") {
            saveErrorMessage = message
            if applyIntervalChanges {
                isIntervalConfirmSaveErrorAlertPresented = true
            } else {
                isSaveErrorAlertPresented = true
            }
            return
        }
        if applyIntervalChanges {
            AppNavigationContext.requestNavigation(to: .reminder)
            return
        }
        dismiss()
    }

    /// 按项目入口编辑时，若原记录包含多个项目，则拆分出当前项目单独保存，避免联动修改同单其他项目。
    func applyLockedItemEdit(
        editingRecord: MaintenanceRecord,
        lockedItemID: UUID,
        selectedCar: Car,
        splitCost: Double,
        splitNote: String
    ) -> Bool {
        let recordBefore = AppDatabaseSnapshot.maintenanceRecord(editingRecord)
        let originalItemIDs = CoreConfig.parseItemIDs(editingRecord.itemIDsRaw)
        guard let lockedIndex = originalItemIDs.firstIndex(of: lockedItemID) else { return false }

        let originalCycleKey = editingRecord.cycleKey
        let targetCycleKey = MaintenanceRecord.cycleKey(carID: selectedCar.id, date: maintenanceDate)
        if originalItemIDs.count == 1 || originalCycleKey == targetCycleKey {
            editingRecord.date = maintenanceDate
            editingRecord.mileage = currentMileage
            editingRecord.car = selectedCar
            editingRecord.cycleKey = targetCycleKey
            editingRecord.itemIDsRaw = CoreConfig.joinItemIDs(originalItemIDs)
            CoreConfig.syncCycleAndRelations(for: editingRecord, in: modelContext)
            AppDatabaseAuditLogger.logUpdate(
                entity: "MaintenanceRecord",
                before: recordBefore,
                after: AppDatabaseSnapshot.maintenanceRecord(editingRecord)
            )
            return true
        }

        var remainingItemIDs = originalItemIDs
        remainingItemIDs.remove(at: lockedIndex)
        editingRecord.itemIDsRaw = CoreConfig.joinItemIDs(remainingItemIDs)
        CoreConfig.syncCycleAndRelations(for: editingRecord, in: modelContext)

        /// 拆分记录时，原单仅剔除当前项目；新单费用默认 0，可在表单中改写。
        let splitRecord = MaintenanceRecord(
            date: maintenanceDate,
            itemIDsRaw: CoreConfig.joinItemIDs([lockedItemID]),
            cost: splitCost,
            mileage: currentMileage,
            note: splitNote,
            car: selectedCar
        )
        modelContext.insertWithAudit(splitRecord)
        CoreConfig.syncCycleAndRelations(for: splitRecord, in: modelContext)
        AppDatabaseAuditLogger.logUpdate(
            entity: "MaintenanceRecord",
            before: recordBefore,
            after: AppDatabaseSnapshot.maintenanceRecord(editingRecord)
        )
        return true
    }
    /// 构建“下次间隔确认”草稿：仅针对本次选择的保养项目。
    func prepareIntervalConfirmationDrafts(for itemIDs: [UUID]) {
        var drafts: [MaintenanceIntervalDraft] = []

        for itemID in itemIDs {
            guard let option = scopedServiceItemOptions.first(where: { $0.id == itemID }) else {
                continue
            }

            let defaultMileage = option.mileageInterval == 0 ? 5_000 : option.mileageInterval
            let defaultMonths = max(1, option.monthInterval)
            let defaultYears = max(0.5, Double(defaultMonths) / 12.0)

            drafts.append(
                MaintenanceIntervalDraft(
                    id: option.id,
                    name: option.name,
                    remindByMileage: option.remindByMileage,
                    mileageInterval: defaultMileage,
                    remindByTime: option.remindByTime,
                    yearInterval: defaultYears
                )
            )
        }

        intervalConfirmDrafts = drafts
    }

    /// 当前选中项目按展示顺序生成，保证落库顺序稳定。
    var orderedSelectedItemIDs: [UUID] {
        availableItemOptions.map(\.id).filter { selectedItems.contains($0) }
    }

    /// 把确认结果回写为全局默认提醒间隔。
    func applyIntervalConfirmationToOptions() {
        for draft in intervalConfirmDrafts {
            guard let option = scopedServiceItemOptions.first(where: { $0.id == draft.id }) else {
                continue
            }

            if option.remindByMileage {
                option.mileageInterval = max(1, draft.mileageInterval)
            }

            if option.remindByTime {
                let months = max(1, Int((draft.yearInterval * 12).rounded()))
                option.monthInterval = months
            }
        }
    }

    /// 在确认页点击“保存”后，一次性保存保养记录和提醒默认值。
    func applyIntervalConfirmationAndDismiss() {
        saveRecord(applyIntervalChanges: true)
    }

    /// 重复周期时直接跳转到“保养记录”页。
    func openDuplicateCycleRecordEditor() {
        AppNavigationContext.requestNavigation(to: .records)
    }

}
