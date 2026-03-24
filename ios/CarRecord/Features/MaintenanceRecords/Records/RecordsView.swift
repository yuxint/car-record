import SwiftUI
import SwiftData

/// 保养记录列表页：读取本地保养记录并支持新增。
struct RecordsView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse)
    var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse)
    var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward)
    var serviceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) var appliedCarIDRaw = ""

    @State var displayMode: LogDisplayMode = .byDate
    @State var editingTarget: MaintenanceRecordEditTarget?
    @State var cycleFilters = LogFilterState()
    @State var itemFilters = LogFilterState()
    @State var isCycleFilterExpanded = false
    @State var isItemFilterExpanded = false
    @State var selectionSheetTarget: FilterSelectionSheetTarget?
    @State var selectionDraftIDs: Set<UUID> = []
    @State var hasInteractedWithSelectionDraft = false
    @State var saveErrorMessage = ""
    @State var isSaveErrorAlertPresented = false

    var body: some View {
        List {
            if let appliedCar = scopedCars.first {
                Section(CarDisplayFormatter.name(appliedCar)) {
                    Picker("展示方式", selection: $displayMode) {
                        ForEach(LogDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } else {
                Section {
                    Picker("展示方式", selection: $displayMode) {
                        ForEach(LogDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if scopedMaintenanceRecords.isEmpty {
                Text("还没有保养记录。")
                    .foregroundStyle(.secondary)
            } else {
                if displayMode == .byDate {
                    Section {
                        filterPanel(
                            filters: $cycleFilters,
                            mode: .byDate,
                            isExpanded: $isCycleFilterExpanded
                        )
                    }

                    Section(cycleSectionTitle) {
                        if filteredDateGroups.isEmpty {
                            Text("暂无符合筛选条件的记录。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredDateGroups) { group in
                                dateGroupRow(group)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteRecords(group.records)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    Section {
                        filterPanel(
                            filters: $itemFilters,
                            mode: .byItem,
                            isExpanded: $isItemFilterExpanded
                        )
                    }

                    Section(itemSectionTitle) {
                        if filteredItemRows.isEmpty {
                            Text("暂无符合筛选条件的记录。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredItemRows) { row in
                                itemRow(row)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteItemRow(row)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("保养记录")
        .toolbar(editingTarget == nil ? .visible : .hidden, for: .tabBar)
        .animation(.none, value: editingTarget != nil)
        .navigationDestination(isPresented: Binding(
            get: { editingTarget != nil },
            set: { if !$0 { editingTarget = nil } }
        )) {
            if let target = editingTarget {
                AddMaintenanceRecordView(
                    editingRecord: target.record,
                    lockedItemID: target.lockedItemID
                )
            }
        }
        .sheet(item: $selectionSheetTarget) { target in
            selectionSheet(target)
        }
        .alert(AppAlertText.operationFailedTitle, isPresented: $isSaveErrorAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .onAppear {
            syncAppliedCarSelection()
            normalizeFilterSelectionsForAppliedCar()
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            syncAppliedCarSelection()
            normalizeFilterSelectionsForAppliedCar()
        }
        .onChange(of: appliedCarIDRaw) { _, _ in
            normalizeFilterSelectionsForAppliedCar()
        }
    }
}
