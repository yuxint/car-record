import SwiftUI
import SwiftData

extension RecordsView {
    /// 日期维度的聚合卡片：单层展示，不使用展开折叠。
    @ViewBuilder
    func dateGroupRow(_ group: MaintenanceDateGroup) -> some View {
        let rawCarNames = group.records.compactMap(\.car).map(CarDisplayFormatter.name)
        let carNames = Array(Set(rawCarNames))
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
        let minMileage = group.records.map(\.mileage).min()
        let maxMileage = group.records.map(\.mileage).max()

        VStack(alignment: .leading, spacing: 6) {
            Text(DateTextFormatter.shortDate(group.date))
                .font(.headline)

            if group.records.count == 1, let singleRecord = group.records.first {
                if let car = singleRecord.car {
                    Text(CarDisplayFormatter.name(car))
                        .foregroundStyle(.secondary)
                }
                Text("里程：\(singleRecord.mileage) km")
                    .foregroundStyle(.secondary)
            } else {
                Text("涉及车辆：\(carNames.joined(separator: "、"))")
                    .foregroundStyle(.secondary)
                if let minMileage, let maxMileage {
                    if minMileage == maxMileage {
                        Text("里程：\(minMileage) km")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("里程：\(maxMileage) km")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("项目：\(group.itemSummary)")
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("总费用：\(CurrencyFormatter.value(group.totalCost))")
                .foregroundStyle(.secondary)

            if group.records.count == 1, let singleRecord = group.records.first {
                Button("编辑本次保养") {
                    openEditRecord(singleRecord)
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    /// 保养项目维度的行视图，点击可编辑所属保养记录。
    @ViewBuilder
    func itemRow(_ row: MaintenanceItemRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.itemName)
                .font(.headline)
            Text(row.carName)
                .foregroundStyle(.secondary)
            Text("保养时间：\(DateTextFormatter.shortDate(row.record.date))")
                .foregroundStyle(.secondary)
            Text("里程：\(row.record.mileage) km")
                .foregroundStyle(.secondary)

            Button("编辑本次保养") {
                openEditRecord(row.record, lockedItemID: row.itemID)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    /// 统一打开编辑表单。
    func openEditRecord(_ record: MaintenanceRecord, lockedItemID: UUID? = nil) {
        editingTarget = MaintenanceRecordEditTarget(record: record, lockedItemID: lockedItemID)
    }

    /// 删除保养记录并立即保存，确保列表与本地数据一致。
    func deleteRecords(_ records: [MaintenanceRecord]) {
        let recordIDs = Set(records.map(\MaintenanceRecord.id))
        for record in records {
            modelContext.delete(record)
        }
        if let editingTarget, recordIDs.contains(editingTarget.record.id) {
            self.editingTarget = nil
        }
        if let message = modelContext.saveOrLog("删除保养记录") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
        }
    }

    /// “按项目”删除：优先只移除当前项目；仅剩 1 个项目时删除整条记录。
    func deleteItemRow(_ row: MaintenanceItemRow) {
        let originalItemIDs = MaintenanceItemCatalog.parseItemIDs(row.record.itemIDsRaw)
        guard !originalItemIDs.isEmpty else {
            deleteRecords([row.record])
            return
        }

        if originalItemIDs.count == 1 {
            deleteRecords([row.record])
            return
        }

        var updatedItemIDs = originalItemIDs
        if let firstMatchIndex = updatedItemIDs.firstIndex(of: row.itemID) {
            updatedItemIDs.remove(at: firstMatchIndex)
        } else {
            return
        }

        if updatedItemIDs.isEmpty {
            deleteRecords([row.record])
            return
        }

        row.record.itemIDsRaw = MaintenanceItemCatalog.joinItemIDs(updatedItemIDs)
        MaintenanceItemCatalog.syncCycleAndRelations(for: row.record, in: modelContext)
        if let message = modelContext.saveOrLog("删除项目维度保养记录") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
        }
    }

}
