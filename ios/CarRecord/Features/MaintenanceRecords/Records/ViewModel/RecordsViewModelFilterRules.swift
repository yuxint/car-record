import Foundation
import SwiftData

extension RecordsViewModel {
    func matchesCycleFilters(record: MaintenanceRecord, filters: LogFilterState) -> Bool {
        if filters.selectedCarIDs.isEmpty == false {
            guard let carID = record.car?.id, filters.selectedCarIDs.contains(carID) else {
                return false
            }
        }

        if let selectedYear = filters.selectedYear {
            let recordYear = Calendar.current.component(.year, from: record.date)
            if recordYear != selectedYear {
                return false
            }
        }
        return true
    }

    func matchesCycleItemFilter(group: MaintenanceDateGroup, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        return group.records.contains { record in
            matchesItemSelection(itemIDsRaw: record.itemIDsRaw, selectedItemIDs: selectedItemIDs)
        }
    }

    func matchesItemSelection(rowItemID: UUID, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        return selectedItemIDs.contains(rowItemID)
    }

    func matchesItemSelection(itemIDsRaw: String, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        let itemIDs = Set(CoreConfig.parseItemIDs(itemIDsRaw))
        guard itemIDs.isEmpty == false else { return false }
        return itemIDs.isDisjoint(with: selectedItemIDs) == false
    }

    func deleteRecords(_ records: [MaintenanceRecord], modelContext: ModelContext) {
        let recordIDs = Set(records.map(\MaintenanceRecord.id))
        for record in records {
            modelContext.deleteWithAudit(record)
        }
        if let editingTarget, recordIDs.contains(editingTarget.record.id) {
            self.editingTarget = nil
        }
        if let message = modelContext.saveOrLog("删除保养记录") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
        }
    }

    func deleteItemRow(_ row: MaintenanceItemRow, modelContext: ModelContext) {
        let originalItemIDs = CoreConfig.parseItemIDs(row.record.itemIDsRaw)
        guard originalItemIDs.isEmpty == false else {
            deleteRecords([row.record], modelContext: modelContext)
            return
        }

        if originalItemIDs.count == 1 {
            deleteRecords([row.record], modelContext: modelContext)
            return
        }

        var updatedItemIDs = originalItemIDs
        if let firstMatchIndex = updatedItemIDs.firstIndex(of: row.itemID) {
            updatedItemIDs.remove(at: firstMatchIndex)
        } else {
            return
        }

        if updatedItemIDs.isEmpty {
            deleteRecords([row.record], modelContext: modelContext)
            return
        }

        let recordBefore = AppDatabaseSnapshot.maintenanceRecord(row.record)
        row.record.itemIDsRaw = CoreConfig.joinItemIDs(updatedItemIDs)
        CoreConfig.syncCycleAndRelations(for: row.record, in: modelContext)
        AppDatabaseAuditLogger.logUpdate(
            entity: "MaintenanceRecord",
            before: recordBefore,
            after: AppDatabaseSnapshot.maintenanceRecord(row.record)
        )
        if let message = modelContext.saveOrLog("删除项目维度保养记录") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
        }
    }

    func toggleDraftSelection(_ id: UUID, target: FilterSelectionSheetTarget, allIDs: Set<UUID>) {
        guard allIDs.contains(id) else { return }

        var workingSelection = effectiveDraftSelection(target: target, allIDs: allIDs)
        if workingSelection.contains(id) {
            workingSelection.remove(id)
        } else {
            workingSelection.insert(id)
        }

        hasInteractedWithSelectionDraft = true
        selectionDraftIDs = workingSelection
    }

    func effectiveDraftSelection(target: FilterSelectionSheetTarget, allIDs: Set<UUID>) -> Set<UUID> {
        guard hasInteractedWithSelectionDraft == false else {
            return selectionDraftIDs
        }
        guard selectionDraftIDs.isEmpty else {
            return selectionDraftIDs
        }

        if currentSelectedIDs(mode: target.mode, kind: target.kind).isEmpty {
            return allIDs
        }
        return selectionDraftIDs
    }

    func applySelectionDraft(target: FilterSelectionSheetTarget, allIDs: Set<UUID>) {
        var normalized = effectiveDraftSelection(target: target, allIDs: allIDs)
        if normalized.isEmpty {
            return
        }
        if normalized == allIDs {
            normalized = []
        }

        switch (target.mode, target.kind) {
        case (.byDate, .car):
            cycleFilters.selectedCarIDs = normalized
        case (.byDate, .item):
            cycleFilters.selectedItemIDs = normalized
        case (.byItem, .car):
            itemFilters.selectedCarIDs = normalized
        case (.byItem, .item):
            itemFilters.selectedItemIDs = normalized
        }

        selectionSheetTarget = nil
    }
}
