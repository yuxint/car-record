import SwiftUI
import SwiftData

/// 保养记录列表页：负责 UI 展示与交互绑定。
struct RecordsView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse)
    var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse)
    var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward)
    var serviceItemOptions: [MaintenanceItemOption]

    @StateObject var viewModel = RecordsViewModel()

    private var scopedCars: [Car] {
        viewModel.scopedCars(cars: cars)
    }

    private var scopedMaintenanceRecords: [MaintenanceRecord] {
        viewModel.scopedMaintenanceRecords(cars: cars, serviceRecords: serviceRecords)
    }

    private var filteredDateGroups: [MaintenanceDateGroup] {
        viewModel.filteredDateGroups(
            cars: cars,
            serviceRecords: serviceRecords,
            serviceItemOptions: serviceItemOptions
        )
    }

    private var filteredItemRows: [MaintenanceItemRow] {
        viewModel.filteredItemRows(
            cars: cars,
            serviceRecords: serviceRecords,
            serviceItemOptions: serviceItemOptions
        )
    }

    private var cycleSectionTitle: String {
        viewModel.cycleSectionTitle(filteredDateGroups: filteredDateGroups)
    }

    private var itemSectionTitle: String {
        viewModel.itemSectionTitle(filteredItemRows: filteredItemRows)
    }

    var body: some View {
        List {
            if let appliedCar = scopedCars.first {
                Section(CarDisplayFormatter.name(appliedCar)) {
                    Picker("展示方式", selection: $viewModel.displayMode) {
                        ForEach(LogDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } else {
                Section {
                    Picker("展示方式", selection: $viewModel.displayMode) {
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
                if viewModel.displayMode == .byDate {
                    Section(cycleSectionTitle) {
                        if filteredDateGroups.isEmpty {
                            Text("暂无符合筛选条件的记录。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredDateGroups) { group in
                                dateGroupRow(group)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteRecords(group.records, modelContext: modelContext)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    Section(itemSectionTitle) {
                        if filteredItemRows.isEmpty {
                            Text("暂无符合筛选条件的记录。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredItemRows) { row in
                                itemRow(row)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteItemRow(row, modelContext: modelContext)
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
        .toolbar((viewModel.editingTarget == nil && viewModel.isAddingMaintenanceRecord == false) ? .visible : .hidden, for: .tabBar)
        .animation(.none, value: viewModel.editingTarget != nil || viewModel.isAddingMaintenanceRecord)
        .toolbar {
            if scopedCars.isEmpty == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isAddingMaintenanceRecord = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $viewModel.isAddingMaintenanceRecord) {
            AddMaintenanceRecordView()
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.editingTarget != nil },
            set: { if !$0 { viewModel.editingTarget = nil } }
        )) {
            if let target = viewModel.editingTarget {
                AddMaintenanceRecordView(
                    editingRecord: target.record,
                    lockedItemID: target.lockedItemID
                )
            }
        }
        .sheet(item: $viewModel.selectionSheetTarget) { target in
            selectionSheet(target)
        }
        .alert(AppAlertText.operationFailedTitle, isPresented: $viewModel.isSaveErrorAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(viewModel.saveErrorMessage)
        }
        .onAppear {
            viewModel.syncAppliedCarSelection(cars: cars)
            viewModel.normalizeFilterSelectionsForAppliedCar(cars: cars)
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            viewModel.syncAppliedCarSelection(cars: cars)
            viewModel.normalizeFilterSelectionsForAppliedCar(cars: cars)
        }
    }
}
