import SwiftUI
import SwiftData

/// 新增/编辑车辆页：全部使用选择器，避免唤醒系统输入法。
struct AddCarView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) var maintenanceItemOptions: [MaintenanceItemOption]

    @StateObject var viewModel: AddCarViewModel
    @State var isMileagePickerPresented = false
    @State var isOnRoadDatePickerPresented = false
    @State var draftValidationMessage = ""
    @State var isDraftValidationAlertPresented = false

    init(editingCar: Car? = nil) {
        _viewModel = StateObject(wrappedValue: AddCarViewModel(editingCar: editingCar))
    }

    var body: some View {
        addCarForm
    }

    private var scopedMaintenanceItemOptions: [MaintenanceItemOption] {
        CoreConfig.scopedOptions(
            maintenanceItemOptions,
            carID: viewModel.editingCar?.id
        )
    }

    private var addCarForm: some View {
        Form {
            vehicleSection
            mileageSection
            maintenanceItemsSection
        }
        .navigationTitle(viewModel.navigationTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if viewModel.saveCar(
                        cars: cars,
                        maintenanceItemOptions: scopedMaintenanceItemOptions,
                        serviceRecords: serviceRecords,
                        modelContext: modelContext
                    ) {
                        dismiss()
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .onChange(of: viewModel.brand) { _, _ in
            viewModel.handleBrandChanged(maintenanceItemOptions: scopedMaintenanceItemOptions)
        }
        .onChange(of: viewModel.modelName) { _, _ in
            viewModel.handleModelChanged(maintenanceItemOptions: scopedMaintenanceItemOptions)
        }
        .onAppear {
            viewModel.handleAppear(maintenanceItemOptions: scopedMaintenanceItemOptions)
        }
        .onChange(of: maintenanceItemOptions.map(\.id)) { _, _ in
            viewModel.handleMaintenanceOptionsChanged(maintenanceItemOptions: scopedMaintenanceItemOptions)
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
                if viewModel.editingCar == nil {
                    下拉单选选择器(
                        options: viewModel.brandOptions,
                        selection: $viewModel.brand
                    )
                } else {
                    Text(viewModel.brand)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("车型")
                Spacer()
                if viewModel.editingCar == nil {
                    下拉单选选择器(
                        options: viewModel.displayModelOptions,
                        selection: $viewModel.modelName
                    )
                } else {
                    Text(viewModel.modelName)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("上路日期")
                Spacer()
                if viewModel.editingCar == nil {
                    Button {
                        isOnRoadDatePickerPresented = true
                    } label: {
                        rowValueActionLabel(text: AppDateContext.formatShortDate(viewModel.onRoadDate))
                    }
                    .sheet(isPresented: $isOnRoadDatePickerPresented) {
                        onRoadDatePickerSheet
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(AppDateContext.formatShortDate(viewModel.onRoadDate))
                        .foregroundStyle(.secondary)
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

    @ViewBuilder
    private var maintenanceItemsSection: some View {
        Section {
            if scopedMaintenanceItemOptions.isEmpty {
                ForEach(viewModel.itemDrafts) { draft in
                    draftRow(draft)
                }
            } else {
                ForEach(viewModel.displayExistingItemDrafts) { draft in
                    existingDraftRow(draft)
                }
            }

            Button {
                viewModel.customDraft = viewModel.makeDefaultCustomDraft()
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if draft.isDefault == false {
                Button(role: .destructive) {
                    viewModel.tryRemoveExistingCustomDraft(draft.id, serviceRecords: serviceRecords)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    private func rowValueActionLabel(text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .id(text)
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
                    onRestoreDefaults: draftBinding.wrappedValue.isDefault ? {
                        draftBinding.wrappedValue = viewModel.restoreDraftDefaults(draftBinding.wrappedValue)
                    } : nil,
                    canRestoreDefaults: viewModel.canRestoreDraftDefaults(draftBinding.wrappedValue),
                    onSave: {
                        let draft = draftBinding.wrappedValue
                        if let message = viewModel.validateDraftError(draft, excludingID: draft.id) {
                            draftValidationMessage = message
                            isDraftValidationAlertPresented = true
                            return
                        }
                        viewModel.draftSheetTarget = nil
                    },
                    validationMessage: draftValidationMessage,
                    isValidationAlertPresented: $isDraftValidationAlertPresented
                )
            }
        case .addCustom:
            maintenanceDraftEditorPage(
                title: "新增自定义项目",
                draft: $viewModel.customDraft,
                canEditName: true,
                onDelete: nil,
                onRestoreDefaults: nil,
                canRestoreDefaults: false,
                onSave: {
                    if scopedMaintenanceItemOptions.isEmpty {
                        if let message = viewModel.validateDraftError(viewModel.customDraft, excludingID: nil) {
                            draftValidationMessage = message
                            isDraftValidationAlertPresented = true
                            return
                        }
                        viewModel.itemDrafts.append(viewModel.customDraft)
                    } else {
                        if let message = viewModel.validateExistingDraftError(viewModel.customDraft, excludingID: nil) {
                            draftValidationMessage = message
                            isDraftValidationAlertPresented = true
                            return
                        }
                        viewModel.existingItemDrafts.append(viewModel.customDraft)
                    }
                    viewModel.draftSheetTarget = nil
                },
                validationMessage: draftValidationMessage,
                isValidationAlertPresented: $isDraftValidationAlertPresented
            )
        case .editExisting(let optionID):
            if let draftBinding = viewModel.existingDraftBinding(optionID: optionID) {
                maintenanceDraftEditorPage(
                    title: "保养项目设置",
                    draft: draftBinding,
                    canEditName: draftBinding.wrappedValue.isDefault == false,
                    onDelete: nil,
                    onRestoreDefaults: draftBinding.wrappedValue.isDefault ? {
                        draftBinding.wrappedValue = viewModel.restoreDraftDefaults(draftBinding.wrappedValue)
                    } : nil,
                    canRestoreDefaults: viewModel.canRestoreDraftDefaults(draftBinding.wrappedValue),
                    onSave: {
                        let draft = draftBinding.wrappedValue
                        if let message = viewModel.validateExistingDraftError(draft, excludingID: draft.id) {
                            draftValidationMessage = message
                            isDraftValidationAlertPresented = true
                            return
                        }
                        viewModel.draftSheetTarget = nil
                    },
                    validationMessage: draftValidationMessage,
                    isValidationAlertPresented: $isDraftValidationAlertPresented
                )
            }
        }
    }
}

private struct 下拉单选选择器: View {
    let options: [String]
    @Binding var selection: String

    private var chevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        Text(option)
                        if selection == option {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ZStack(alignment: .trailing) {
                ForEach(options, id: \.self) { option in
                    HStack(spacing: 4) {
                        Text(option)
                            .lineLimit(1)
                        chevron
                    }
                    .hidden()
                }

                HStack(spacing: 4) {
                    Text(selection)
                        .lineLimit(1)
                    chevron
                }
            }
        }
    }
}
