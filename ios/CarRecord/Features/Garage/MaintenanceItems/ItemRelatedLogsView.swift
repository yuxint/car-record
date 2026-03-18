import SwiftUI
import SwiftData
import Foundation

/// 标识“去处理记录”时需要打开的项目。
struct MaintenanceItemHandleTarget: Identifiable {
    let itemID: UUID
    let itemName: String

    var id: String { itemID.uuidString }
}

/// 某个保养项目的关联记录处理页：支持编辑或删除。
struct ItemRelatedLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var serviceRecords: [MaintenanceRecord]

    let itemID: UUID
    let itemName: String

    @State private var editingRecord: MaintenanceRecord?
    @State private var operationErrorMessage = ""
    @State private var isOperationErrorAlertPresented = false

    private var relatedLogs: [MaintenanceRecord] {
        serviceRecords.filter {
            $0.car != nil && MaintenanceItemCatalog.contains(itemID: itemID, in: $0.itemIDsRaw)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if relatedLogs.isEmpty {
                    Text("当前项目已无关联记录，可以返回继续删除该项目。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(relatedLogs) { log in
                        VStack(alignment: .leading, spacing: 6) {
                            if let car = log.car {
                                Text(CarDisplayFormatter.name(car))
                                    .font(.headline)
                            }
                            Text("保养时间：\(DateTextFormatter.shortDate(log.date))")
                                .foregroundStyle(.secondary)
                            Text("里程：\(log.mileage) km")
                                .foregroundStyle(.secondary)
                            Text("总费用：\(CurrencyFormatter.value(log.cost))")
                                .foregroundStyle(.secondary)

                            Button("编辑该记录") {
                                editingRecord = log
                            }
                            .buttonStyle(.borderless)
                            .font(.subheadline)
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteRelatedLogs)
                }
            }
            .navigationTitle("处理“\(itemName)”记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $editingRecord) { log in
            AddMaintenanceRecordView(
                editingRecord: log,
                lockedItemID: itemID,
                limitToAppliedCar: false
            )
        }
        .alert("操作失败", isPresented: $isOperationErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
    }

    /// 删除关联保养记录。
    private func deleteRelatedLogs(at offsets: IndexSet) {
        let currentRelatedLogs = relatedLogs
        let targetLogs = offsets.compactMap { index in
            currentRelatedLogs.indices.contains(index) ? currentRelatedLogs[index] : nil
        }
        let targetLogIDs = Set(targetLogs.map(\.id))

        for log in targetLogs {
            var itemIDs = MaintenanceItemCatalog.parseItemIDs(log.itemIDsRaw)
            if itemIDs.count <= 1 {
                modelContext.delete(log)
                continue
            }

            if let firstMatchIndex = itemIDs.firstIndex(of: itemID) {
                itemIDs.remove(at: firstMatchIndex)
            } else {
                continue
            }

            if itemIDs.isEmpty {
                modelContext.delete(log)
            } else {
                /// 仅移除当前项目，避免误删同单其他保养项目。
                log.itemIDsRaw = MaintenanceItemCatalog.joinItemIDs(itemIDs)
                MaintenanceItemCatalog.syncCycleAndRelations(for: log, in: modelContext)
            }
        }

        if let editingRecord, targetLogIDs.contains(editingRecord.id) {
            self.editingRecord = nil
        }
        if let message = modelContext.saveOrLog("删除保养项目关联记录") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
        }
    }
}
