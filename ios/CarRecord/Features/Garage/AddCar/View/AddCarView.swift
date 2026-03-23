import SwiftUI
import SwiftData

/// 新增/编辑车辆页：全部使用选择器，避免唤醒系统输入法。
struct AddCarView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) var cars: [Car]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) var maintenanceItemOptions: [MaintenanceItemOption]

    @StateObject var viewModel: AddCarViewModel

    init(editingCar: Car? = nil) {
        _viewModel = StateObject(wrappedValue: AddCarViewModel(editingCar: editingCar))
    }

    var body: some View {
        NavigationStack {
            addCarForm
        }
    }

    private var addCarForm: some View {
        Form {
            vehicleSection
            mileageSection
            onRoadSection
            maintenanceItemsSection
        }
        .navigationTitle(viewModel.navigationTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
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
        .sheet(item: $viewModel.activePickerSheet) { sheet in
            switch sheet {
            case .mileage:
                mileagePickerSheet
            case .onRoadDate:
                onRoadDatePickerSheet
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
        .sheet(item: $viewModel.draftSheetTarget) { target in
            draftEditorSheet(target: target)
        }
    }

    private var vehicleSection: some View {
        Section("车辆信息") {
            Picker("品牌", selection: $viewModel.brand) {
                ForEach(viewModel.brandOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }

            Picker("车型", selection: $viewModel.modelName) {
                ForEach(viewModel.displayModelOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        }
    }

    private var mileageSection: some View {
        Section("当前里程") {
            Button {
                viewModel.presentPickerSheet(.mileage)
            } label: {
                HStack {
                    Text("里程")
                    Spacer()
                    Text(MileageSegmentFormatter.text(
                        wan: viewModel.mileageWan,
                        qian: viewModel.mileageQian,
                        bai: viewModel.mileageBai
                    ))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var onRoadSection: some View {
        Section("上路信息") {
            Button {
                viewModel.draftOnRoadDate = viewModel.onRoadDate
                viewModel.presentPickerSheet(.onRoadDate)
            } label: {
                HStack {
                    Text("上路日期")
                    Spacer()
                    Text(AppDateContext.formatShortDate(viewModel.onRoadDate))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("车龄：\(CarAgeFormatter.yearsText(from: viewModel.onRoadDate, now: AppDateContext.now())) 年")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var maintenanceItemsSection: some View {
        Section("保养项目设置") {
            if maintenanceItemOptions.isEmpty {
                ForEach(viewModel.itemDrafts) { draft in
                    draftRow(draft)
                }

                Button {
                    viewModel.customDraft = MaintenanceItemDraft.defaultDraft(name: "自定义项目")
                    viewModel.draftSheetTarget = .addCustom
                } label: {
                    Label("新增自定义项目", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)

                Text("可按需关闭项目，也可点项目进入设置里程/时间提醒规则与阈值。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.existingItemDrafts) { draft in
                    existingDraftRow(draft)
                }

                Text("点任一项目可直接修改名称、提醒规则和阈值；与新增车辆页保持一致。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func draftRow(_ draft: MaintenanceItemDraft) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.draftSheetTarget = .edit(draft.id)
            } label: {
                draftSummary(draft)
            }
            .buttonStyle(.plain)

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
        HStack(spacing: 8) {
            Button {
                viewModel.draftSheetTarget = .editExisting(draft.id)
            } label: {
                draftSummary(draft)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
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
    private func draftEditorSheet(target: MaintenanceDraftSheetTarget) -> some View {
        switch target {
        case .edit(let draftID):
            if let draftBinding = viewModel.draftBinding(id: draftID) {
                maintenanceDraftEditorSheet(
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
            maintenanceDraftEditorSheet(
                title: "新增自定义项目",
                draft: $viewModel.customDraft,
                canEditName: true,
                onDelete: nil,
                onSave: {
                    guard viewModel.validateDraft(viewModel.customDraft, excludingID: nil) else { return }
                    viewModel.itemDrafts.append(viewModel.customDraft)
                    viewModel.draftSheetTarget = nil
                }
            )
        case .editExisting(let optionID):
            if let draftBinding = viewModel.existingDraftBinding(optionID: optionID) {
                maintenanceDraftEditorSheet(
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
