import SwiftUI
import SwiftData

/// 新增/编辑车辆页：全部使用选择器，避免唤醒系统输入法。
struct AddCarView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) var cars: [Car]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) var maintenanceItemOptions: [MaintenanceItemOption]

    @StateObject var viewModel: AddCarViewModel
    @State var isMileagePickerPresented = false
    @State var isOnRoadDatePickerPresented = false

    init(editingCar: Car? = nil) {
        _viewModel = StateObject(wrappedValue: AddCarViewModel(editingCar: editingCar))
    }

    var body: some View {
        addCarForm
    }

    private var addCarForm: some View {
        Form {
            vehicleSection
            mileageSection
            onRoadSection
            maintenanceItemsSection
        }
        .navigationTitle(viewModel.navigationTitle)
        .toolbar(viewModel.editingCar == nil ? .visible : .hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if viewModel.saveCar(
                        cars: cars,
                        maintenanceItemOptions: maintenanceItemOptions,
                        modelContext: modelContext
                    ) {
                        dismiss()
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .onChange(of: viewModel.brand) { _, _ in
            viewModel.handleBrandChanged(maintenanceItemOptions: maintenanceItemOptions)
        }
        .onChange(of: viewModel.modelName) { _, _ in
            viewModel.handleModelChanged(maintenanceItemOptions: maintenanceItemOptions)
        }
        .onAppear {
            viewModel.handleAppear(maintenanceItemOptions: maintenanceItemOptions)
        }
        .onChange(of: maintenanceItemOptions.map(\.id)) { _, _ in
            viewModel.handleMaintenanceOptionsChanged(maintenanceItemOptions: maintenanceItemOptions)
        }
        .alert("保存失败", isPresented: $viewModel.isSaveErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(viewModel.saveErrorMessage)
        }
        .alert("提示", isPresented: $viewModel.isValidationAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(viewModel.validationMessage)
        }
        .navigationDestination(item: $viewModel.draftSheetTarget) { target in
            draftEditorPage(target: target)
        }
    }

    private var vehicleSection: some View {
        Section("车辆信息") {
            HStack {
                Text("品牌")
                Spacer()
                Menu {
                    ForEach(viewModel.brandOptions, id: \.self) { option in
                        Button(option) {
                            viewModel.brand = option
                        }
                    }
                } label: {
                    rowValueActionLabel(text: viewModel.brand)
                }
            }

            HStack {
                Text("车型")
                Spacer()
                Menu {
                    ForEach(viewModel.displayModelOptions, id: \.self) { option in
                        Button(option) {
                            viewModel.modelName = option
                        }
                    }
                } label: {
                    rowValueActionLabel(text: viewModel.modelName)
                }
            }
        }
    }

    private var mileageSection: some View {
        Section("当前里程") {
            HStack {
                Text("里程")
                Spacer()
                Button {
                    isMileagePickerPresented = true
                } label: {
                    rowValueActionLabel(
                        text: MileageSegmentFormatter.text(
                            wan: viewModel.mileageWan,
                            qian: viewModel.mileageQian,
                            bai: viewModel.mileageBai
                        )
                    )
                }
                .sheet(isPresented: $isMileagePickerPresented) {
                    mileagePickerSheet
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var onRoadSection: some View {
        Section("上路信息") {
            HStack {
                Text("上路日期")
                Spacer()
                Button {
                    isOnRoadDatePickerPresented = true
                } label: {
                    rowValueActionLabel(text: AppDateContext.formatShortDate(viewModel.onRoadDate))
                }
                .sheet(isPresented: $isOnRoadDatePickerPresented) {
                    onRoadDatePickerSheet
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var maintenanceItemsSection: some View {
        Section {
            if maintenanceItemOptions.isEmpty {
                ForEach(viewModel.itemDrafts) { draft in
                    draftRow(draft)
                }
            } else {
                ForEach(viewModel.displayExistingItemDrafts) { draft in
                    existingDraftRow(draft)
                }
            }

            Button {
                viewModel.customDraft = MaintenanceItemDraft.defaultDraft(name: "自定义项目")
                viewModel.draftSheetTarget = .addCustom
            } label: {
                Label("新增自定义项目", systemImage: "plus.circle")
            }
        } header: {
            Text("保养项目设置")
        } footer: {
            Text("可按需关闭项目，也可点项目进入设置里程/时间提醒规则与阈值。")
        }
    }

    private func draftRow(_ draft: MaintenanceItemDraft) -> some View {
        HStack(spacing: 12) {
            draftSummary(draft)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.draftSheetTarget = .edit(draft.id)
                }

            Toggle("", isOn: viewModel.draftEnabledBinding(id: draft.id))
                .labelsHidden()
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if draft.isDefault == false {
                Button(role: .destructive) {
                    viewModel.removeCustomDraft(draft.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    private func existingDraftRow(_ draft: MaintenanceItemDraft) -> some View {
        HStack(spacing: 12) {
            draftSummary(draft)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.draftSheetTarget = .editExisting(draft.id)
                }

            Toggle("", isOn: viewModel.existingDraftEnabledBinding(id: draft.id))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private func rowValueActionLabel(text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func draftSummary(_ draft: MaintenanceItemDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(draft.name)
                    .lineLimit(1)
                Text(draft.isDefault ? "默认" : "自定义")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            Text("提醒：\(MaintenanceItemDraft.reminderSummary(for: draft))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func draftEditorPage(target: MaintenanceDraftSheetTarget) -> some View {
        switch target {
        case .edit(let draftID):
            if let draftBinding = viewModel.draftBinding(id: draftID) {
                maintenanceDraftEditorPage(
                    title: "保养项目设置",
                    draft: draftBinding,
                    canEditName: draftBinding.wrappedValue.isDefault == false,
                    onDelete: draftBinding.wrappedValue.isDefault ? nil : {
                        viewModel.removeCustomDraft(draftID)
                        viewModel.draftSheetTarget = nil
                    },
                    onSave: {
                        let draft = draftBinding.wrappedValue
                        guard viewModel.validateDraft(draft, excludingID: draft.id) else { return }
                        viewModel.draftSheetTarget = nil
                    }
                )
            }
        case .addCustom:
            maintenanceDraftEditorPage(
                title: "新增自定义项目",
                draft: $viewModel.customDraft,
                canEditName: true,
                onDelete: nil,
                onSave: {
                    if maintenanceItemOptions.isEmpty {
                        guard viewModel.validateDraft(viewModel.customDraft, excludingID: nil) else { return }
                        viewModel.itemDrafts.append(viewModel.customDraft)
                    } else {
                        guard viewModel.validateExistingDraft(viewModel.customDraft, excludingID: nil) else { return }
                        viewModel.existingItemDrafts.append(viewModel.customDraft)
                    }
                    viewModel.draftSheetTarget = nil
                }
            )
        case .editExisting(let optionID):
            if let draftBinding = viewModel.existingDraftBinding(optionID: optionID) {
                maintenanceDraftEditorPage(
                    title: "保养项目设置",
                    draft: draftBinding,
                    canEditName: true,
                    onDelete: nil,
                    onSave: {
                        let draft = draftBinding.wrappedValue
                        guard viewModel.validateExistingDraft(draft, excludingID: draft.id) else { return }
                        viewModel.draftSheetTarget = nil
                    }
                )
            }
        }
    }
}
