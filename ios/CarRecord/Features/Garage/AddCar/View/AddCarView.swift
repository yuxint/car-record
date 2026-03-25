import SwiftUI
import SwiftData
import Foundation

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
    @State var draftEditorInitialSnapshot: MaintenanceItemDraft?

    init(editingCar: Car? = nil) {
        _viewModel = StateObject(wrappedValue: AddCarViewModel(editingCar: editingCar))
    }

    var body: some View {
        addCarForm
    }

    private var scopedMaintenanceItemOptions: [MaintenanceItemOption] {
        viewModel.scopedMaintenanceItemOptions(from: maintenanceItemOptions)
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
        .alert(AppAlertText.saveFailedTitle, isPresented: $viewModel.isSaveErrorAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(viewModel.saveErrorMessage)
        }
        .alert(AppAlertText.promptTitle, isPresented: $viewModel.isValidationAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(viewModel.validationMessage)
        }
        .navigationDestination(item: $viewModel.draftSheetTarget) { target in
            draftEditorPage(target: target)
        }
        .onChange(of: viewModel.draftSheetTarget) { _, newTarget in
            cacheDraftEditorInitialSnapshot(for: newTarget)
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
                Button {
                    isOnRoadDatePickerPresented = true
                } label: {
                    rowValueActionLabel(text: AppDateContext.formatShortDate(viewModel.onRoadDate))
                }
                .sheet(isPresented: $isOnRoadDatePickerPresented) {
                    onRoadDatePickerSheet
                }
                .buttonStyle(.plain)
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
            Text("可按需关闭项目，也可点项目进入设置里程/时间提醒规则。")
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
            Text("提醒：\(reminderSummaryText(for: draft))")
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
                    confirmButtonTitle: "完成",
                    isConfirmButtonEnabled: viewModel.hasDraftChanges(
                        current: draftBinding.wrappedValue,
                        initial: draftEditorInitialSnapshot
                    ),
                    onSave: {
                        let draft = draftBinding.wrappedValue
                        if let message = viewModel.validateEditorDraftMessage(draft, target: target) {
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
                confirmButtonTitle: "添加",
                isConfirmButtonEnabled: true,
                onSave: {
                    if let message = viewModel.addCustomDraftMessage(
                        usingExistingOptions: scopedMaintenanceItemOptions.isEmpty == false
                    ) {
                        draftValidationMessage = message
                        isDraftValidationAlertPresented = true
                        return
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
                    confirmButtonTitle: "完成",
                    isConfirmButtonEnabled: viewModel.hasDraftChanges(
                        current: draftBinding.wrappedValue,
                        initial: draftEditorInitialSnapshot
                    ),
                    onSave: {
                        let draft = draftBinding.wrappedValue
                        if let message = viewModel.validateEditorDraftMessage(draft, target: target) {
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

    private func cacheDraftEditorInitialSnapshot(for target: MaintenanceDraftSheetTarget?) {
        guard let target else {
            draftEditorInitialSnapshot = nil
            return
        }
        switch target {
        case .edit(let id):
            draftEditorInitialSnapshot = viewModel.itemDrafts.first(where: { $0.id == id })
        case .editExisting(let id):
            draftEditorInitialSnapshot = viewModel.existingItemDrafts.first(where: { $0.id == id })
        case .addCustom:
            draftEditorInitialSnapshot = nil
        }
    }

    private func reminderSummaryText(for draft: MaintenanceItemDraft) -> String {
        var parts: [String] = []
        if draft.remindByMileage {
            parts.append(MileageDisplayFormatter.reminderDistanceText(for: max(1, draft.mileageInterval)))
        }
        if draft.remindByTime {
            let years = Double(max(1, draft.monthInterval)) / 12.0
            let yearText: String
            if years.truncatingRemainder(dividingBy: 1) == 0 {
                yearText = "\(Int(years))年"
            } else {
                yearText = "\(String(format: "%.1f", years))年"
            }
            parts.append(yearText)
        }
        if parts.isEmpty {
            parts.append("未设置")
        }
        return parts.joined(separator: " / ")
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
