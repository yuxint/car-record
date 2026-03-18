import SwiftUI
import SwiftData

struct MaintenanceItemManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) private var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var serviceItemOptions: [MaintenanceItemOption]

    @State private var customItemName = ""
    @State private var deleteBlockedItemName = ""
    @State private var deleteBlockedItemID: UUID?
    @State private var deleteBlockedLogCount = 0
    @State private var isDeleteBlockedAlertPresented = false
    @State private var isRestoreDefaultsAlertPresented = false
    @State private var logHandlingTarget: MaintenanceItemHandleTarget?
    @State private var operationErrorMessage = ""
    @State private var isOperationErrorAlertPresented = false

    /// 项目关联记录处理目标。
    struct MaintenanceItemHandleTarget: Identifiable {
        let id = UUID()
        let itemID: UUID
        let itemName: String
    }

    var body: some View {
        List {
            Section("新增自定义项目") {
                HStack(spacing: 8) {
                    TextField("新增自定义保养项目", text: $customItemName)
                    Button("添加") {
                        addCustomMaintenanceItem()
                    }
                    .disabled(!canAddCustomMaintenanceItem)
                }
            }

            Section("项目列表") {
                ForEach(sortedMaintenanceItemOptions) { option in
                    NavigationLink {
                        MaintenanceItemReminderSettingView(option: option)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(option.name)
                                    .lineLimit(1)

                                if option.isDefault {
                                    Text("默认")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text("提醒规则：\(MaintenanceItemCatalog.reminderSummary(for: option))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }

                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if option.isDefault == false {
                            Button(role: .destructive) {
                                attemptDeleteCustomMaintenanceItem(option)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("默认配置") {
                Button(role: .destructive) {
                    isRestoreDefaultsAlertPresented = true
                } label: {
                    Text("恢复默认值")
                }
            }
        }
        .navigationTitle("保养项目管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
        .sheet(item: $logHandlingTarget) { target in
            ItemRelatedLogsView(itemID: target.itemID, itemName: target.itemName)
        }
        .alert("无法删除该保养项目", isPresented: $isDeleteBlockedAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("去处理记录") {
                guard let deleteBlockedItemID else { return }
                logHandlingTarget = MaintenanceItemHandleTarget(
                    itemID: deleteBlockedItemID,
                    itemName: deleteBlockedItemName
                )
            }
        } message: {
            Text("“\(deleteBlockedItemName)”已被\(deleteBlockedLogCount)条保养记录使用，请先修改或删除对应记录。")
        }
        .alert("恢复默认值？", isPresented: $isRestoreDefaultsAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                restoreDefaultMaintenanceItems()
            }
        } message: {
            Text("将把默认保养项目名称和提醒规则恢复为初始值，自定义项目保留不变。")
        }
        .alert("操作失败", isPresented: $isOperationErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
    }

    /// 默认项目优先，其次按创建时间展示自定义项目。
    private var sortedMaintenanceItemOptions: [MaintenanceItemOption] {
        MaintenanceItemCatalog.naturalSortedOptions(serviceItemOptions)
    }

    /// 自定义项目新增校验：非空且不与现有项目重名。
    private var canAddCustomMaintenanceItem: Bool {
        let normalized = customItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        return !serviceItemOptions.map(\.name).contains(normalized)
    }

    /// 添加自定义保养项目并持久化。
    private func addCustomMaintenanceItem() {
        let normalized = customItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard !serviceItemOptions.map(\.name).contains(normalized) else { return }

        modelContext.insert(
            MaintenanceItemOption(
                name: normalized,
                isDefault: false,
                remindByMileage: true,
                mileageInterval: 5000,
                remindByTime: false,
                monthInterval: 0,
                warningStartPercent: MaintenanceItemCatalog.defaultWarningStartPercent,
                dangerStartPercent: MaintenanceItemCatalog.defaultDangerStartPercent
            )
        )
        if let message = modelContext.saveOrLog("新增自定义保养项目") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
            return
        }
        customItemName = ""
    }

    /// 尝试删除自定义项目；若存在关联记录，则引导用户先处理记录。
    private func attemptDeleteCustomMaintenanceItem(_ option: MaintenanceItemOption) {
        guard option.isDefault == false else { return }

        let relatedLogs = serviceRecords.filter {
            MaintenanceItemCatalog.contains(itemID: option.id, in: $0.itemIDsRaw)
        }

        if relatedLogs.isEmpty {
            modelContext.delete(option)
            if let message = modelContext.saveOrLog("删除自定义保养项目") {
                operationErrorMessage = message
                isOperationErrorAlertPresented = true
            }
            return
        }

        deleteBlockedItemName = option.name
        deleteBlockedItemID = option.id
        deleteBlockedLogCount = relatedLogs.count
        isDeleteBlockedAlertPresented = true
    }

    /// 恢复默认项目名称与提醒规则。
    private func restoreDefaultMaintenanceItems() {
        let primaryCar = cars.first
        let definitions = MaintenanceItemCatalog.defaultItemDefinitions(
            brand: primaryCar?.brand,
            modelName: primaryCar?.modelName
        )
        for definition in definitions {
            let existingByKey = serviceItemOptions.first(where: { $0.catalogKey == definition.key })

            let option: MaintenanceItemOption
            if let existingByKey {
                option = existingByKey
            } else {
                let newOption = MaintenanceItemOption(
                    name: definition.defaultName,
                    isDefault: true,
                    catalogKey: definition.key,
                    remindByMileage: definition.mileageInterval != nil,
                    mileageInterval: definition.mileageInterval ?? 0,
                    remindByTime: definition.monthInterval != nil,
                    monthInterval: definition.monthInterval ?? 0,
                    warningStartPercent: MaintenanceItemCatalog.defaultWarningStartPercent,
                    dangerStartPercent: MaintenanceItemCatalog.defaultDangerStartPercent
                )
                modelContext.insert(newOption)
                continue
            }

            if let conflict = serviceItemOptions.first(where: { $0.name == definition.defaultName && $0.id != option.id }) {
                modelContext.delete(conflict)
            }

            option.isDefault = true
            option.catalogKey = definition.key
            option.name = definition.defaultName
            option.remindByMileage = definition.mileageInterval != nil
            option.mileageInterval = definition.mileageInterval ?? 0
            option.remindByTime = definition.monthInterval != nil
            option.monthInterval = definition.monthInterval ?? 0
            option.warningStartPercent = MaintenanceItemCatalog.defaultWarningStartPercent
            option.dangerStartPercent = MaintenanceItemCatalog.defaultDangerStartPercent
        }

        if let message = modelContext.saveOrLog("恢复默认保养项目") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
        }
    }
}
