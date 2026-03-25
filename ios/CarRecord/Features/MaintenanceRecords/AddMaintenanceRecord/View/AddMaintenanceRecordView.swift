import SwiftData
import SwiftUI
import UIKit

/// 新增/编辑保养页：支持下拉多选项目、自定义项目、保养时间和里程弹窗选择。
struct AddMaintenanceRecordView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @Query(sort: \Car.purchaseDate, order: .reverse) private var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var serviceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) private var appliedCarIDRaw = ""

    @StateObject var viewModel: AddMaintenanceRecordViewModel
    @State var activePickerSheet: MaintenancePickerSheet?
    @FocusState private var focusedField: FocusField?

    init(
        editingRecord: MaintenanceRecord? = nil,
        lockedItemID: UUID? = nil,
        limitToAppliedCar: Bool = true
    ) {
        _viewModel = StateObject(
            wrappedValue: AddMaintenanceRecordViewModel(
                editingRecord: editingRecord,
                lockedItemID: lockedItemID,
                limitToAppliedCar: limitToAppliedCar
            )
        )
    }

    var body: some View {
        baseFormView
            .sheet(item: $activePickerSheet) { sheet in
                switch sheet {
                case .serviceDate:
                    maintenanceDatePickerSheet
                case .mileage:
                    mileagePickerSheet
                case .serviceItems:
                    maintenanceItemsPickerSheet
                }
            }
            .navigationDestination(isPresented: $viewModel.isIntervalConfirmPresented) {
                intervalConfirmSheet
            }
            .alert(AppAlertText.duplicateCycleTitle, isPresented: $viewModel.isDuplicateCycleAlertPresented) {
                Button(AppPopupText.goEdit) {
                    viewModel.openDuplicateCycleRecordEditor()
                }
                Button(AppPopupText.cancel, role: .cancel) {}
            } message: {
                Text(viewModel.duplicateCycleAlertMessage)
            }
            .alert(
                AppAlertText.saveFailedTitle,
                isPresented: saveErrorAlertBinding
            ) {
                Button(AppPopupText.acknowledge, role: .cancel) {}
            } message: {
                Text(viewModel.saveErrorMessage)
            }
    }

    private var baseFormView: some View {
        addRecordForm
            .navigationTitle(viewModel.isEditing ? "编辑保养" : "新增保养")
            .toolbar { recordToolbar }
            .onAppear {
                refreshViewModelSources()
            }
            .onChange(of: sourceRefreshToken) { _, _ in
                refreshViewModelSources()
            }
            .onChange(of: viewModel.selectedCarID) { _, newValue in
                viewModel.onSelectedCarChanged(newValue)
            }
            .onChange(of: focusedField) { _, newValue in
                viewModel.onCostInputFocusChanged(isFocused: newValue == .cost)
            }
            .onChange(of: viewModel.cost) { _, newValue in
                viewModel.onCostChanged(newValue)
            }
            .onChange(of: viewModel.isSplitEditMode) { _, newValue in
                viewModel.onSplitEditModeChanged(newValue)
            }
    }

    @ToolbarContentBuilder
    private var recordToolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if !isAnyInputActive {
                Button(viewModel.isEditing ? "保存" : "下一步") {
                    closeInputEditors()
                    if viewModel.isEditing {
                        viewModel.saveRecord(modelContext: modelContext, dismiss: dismiss.callAsFunction)
                    } else {
                        viewModel.proceedToIntervalConfirmation()
                    }
                }
                .disabled(!viewModel.canSubmit)
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            if focusedField == .cost, !viewModel.isCostReadOnly {
                Spacer()
                Button("完成") {
                    closeInputEditors()
                }
            }
        }
    }

    private var addRecordForm: some View {
        Form {
            Section("车辆信息") {
                if viewModel.hasAvailableCars == false {
                    Text("请先添加车辆，再记录保养。")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("车辆")
                        Spacer()
                        Text(viewModel.selectedCarDisplayText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("保养时间")
                        Spacer()
                        Button {
                            presentPickerSheet(.serviceDate)
                        } label: {
                            rowValueActionLabel(text: AppDateContext.formatShortDate(viewModel.maintenanceDate))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Text("当前里程")
                        Spacer()
                        Button {
                            presentPickerSheet(.mileage)
                        } label: {
                            rowValueActionLabel(
                                text: MileageSegmentFormatter.text(
                                    wan: viewModel.mileageWan,
                                    qian: viewModel.mileageQian,
                                    bai: viewModel.mileageBai
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("保养项目") {
                if viewModel.isItemSelectionLocked {
                    HStack {
                        Text("选择项目")
                        Spacer()
                        Text(viewModel.lockedItemNameText)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Button {
                        presentPickerSheet(.serviceItems)
                    } label: {
                        HStack {
                            Text("选择项目")
                            Spacer()
                            Text(viewModel.selectedItemsText)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }
            }

            if !viewModel.isCostReadOnly {
                Section("保养费用") {
                    HStack {
                        Text("总费用")
                        Spacer()
                        TextField("请输入", text: $viewModel.cost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .cost)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = .cost
                    }

                    HStack {
                        Text("备注（选填）")
                        Spacer()
                        TextField("请输入", text: $viewModel.note)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .note)
                            .submitLabel(.done)
                            .onSubmit {
                                closeInputEditors()
                            }
                    }
                }
            }
        }
    }

    private var isAnyInputActive: Bool {
        focusedField != nil
    }

    private var sourceRefreshToken: Int {
        var hasher = Hasher()
        for id in cars.map(\.id) {
            hasher.combine(id)
        }
        for id in serviceRecords.map(\.id) {
            hasher.combine(id)
        }
        for id in serviceItemOptions.map(\.id) {
            hasher.combine(id)
        }
        hasher.combine(appliedCarIDRaw)
        return hasher.finalize()
    }

    private var saveErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isEditing && viewModel.isSaveErrorAlertPresented },
            set: { viewModel.isSaveErrorAlertPresented = $0 }
        )
    }

    /// 统一拉起弹窗：先收起键盘，避免出现“要点几次才弹出”的交互问题。
    private func presentPickerSheet(_ sheet: MaintenancePickerSheet) {
        closeInputEditors()
        DispatchQueue.main.async {
            activePickerSheet = sheet
        }
    }

    /// 统一收起当前输入态：用于弹窗切换和键盘右上角“完成”按钮。
    func closeInputEditors() {
        focusedField = nil
        hideKeyboard()
    }

    /// 主动结束当前输入，避免键盘占位视图约束冲突。
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func refreshViewModelSources() {
        let normalizedRaw = viewModel.normalizedAppliedCarRaw(appliedCarIDRaw, cars: cars)
        if normalizedRaw != appliedCarIDRaw {
            appliedCarIDRaw = normalizedRaw
        }
        viewModel.updateSources(
            cars: cars,
            serviceRecords: serviceRecords,
            serviceItemOptions: serviceItemOptions,
            appliedCarIDRaw: appliedCarIDRaw
        )
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
}

enum MaintenancePickerSheet: Identifiable {
    case serviceDate
    case mileage
    case serviceItems

    var id: String {
        switch self {
        case .serviceDate:
            return "serviceDate"
        case .mileage:
            return "mileage"
        case .serviceItems:
            return "serviceItems"
        }
    }
}

/// 输入焦点：用于区分当前是“总费用”还是“备注”在编辑。
private enum FocusField {
    case cost
    case note
}
