import SwiftUI
import SwiftData
import UIKit

/// 新增/编辑保养页：支持下拉多选项目、自定义项目、保养时间和里程弹窗选择。
struct AddMaintenanceRecordView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @Query(sort: \Car.purchaseDate, order: .reverse) var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) var serviceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) var appliedCarIDRaw = ""

    let editingRecord: MaintenanceRecord?
    let lockedItemID: UUID?
    let limitToAppliedCar: Bool

    @State var selectedCarID: UUID?
    @State var selectedItems = Set<UUID>()
    @State var maintenanceDate = AppDateContext.now()
    /// 新增记录默认总费用为 0，避免首次进入为空导致无法直接保存。
    @State var cost = "0"
    @State var mileageWan = 0
    @State var mileageQian = 0
    @State var mileageBai = 0
    @State var note = ""
    @State var initialEditDraftSnapshot: MaintenanceEditDraftSnapshot?
    @State var hasLoadedInitialValues = false
    @State var activePickerSheet: MaintenancePickerSheet?
    @State var intervalConfirmDrafts: [MaintenanceIntervalDraft] = []
    @State var isIntervalConfirmPresented = false
    @State var isDuplicateCycleAlertPresented = false
    @State var isIntervalConfirmDuplicateCycleAlertPresented = false
    @State var duplicateCycleAlertMessage = ""
    @State var saveErrorMessage = ""
    @State var isSaveErrorAlertPresented = false
    @State var isIntervalConfirmSaveErrorAlertPresented = false
    @State var hasInitializedSplitDraft = false
    @FocusState var focusedField: FocusField?

    init(
        editingRecord: MaintenanceRecord? = nil,
        lockedItemID: UUID? = nil,
        limitToAppliedCar: Bool = true
    ) {
        self.editingRecord = editingRecord
        self.lockedItemID = lockedItemID
        self.limitToAppliedCar = limitToAppliedCar
    }

    var body: some View {
        addRecordForm
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: inputAvoidanceBottomInset)
                    .allowsHitTesting(false)
            }
            .navigationTitle(editingRecord == nil ? "新增保养" : "编辑保养")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if !isAnyInputActive {
                        Button(editingRecord == nil ? "下一步" : "保存") {
                            if editingRecord == nil {
                                proceedToIntervalConfirmation()
                            } else {
                                saveRecord()
                            }
                        }
                        .disabled(!canSubmit)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .cost, !isCostReadOnly {
                        Spacer()
                        Button("完成") {
                            closeInputEditors()
                        }
                    }
                }
            }
            .onAppear {
                syncAppliedCarSelectionIfNeeded()
                loadInitialValuesIfNeeded()
                ensureSelectedCarIsValid()
                DispatchQueue.main.async {
                    captureInitialEditDraftSnapshotIfNeeded()
                }
            }
            .onChange(of: cars.map(\.id)) { _, _ in
                syncAppliedCarSelectionIfNeeded()
                ensureSelectedCarIsValid()
            }
            .onChange(of: appliedCarIDRaw) { _, _ in
                ensureSelectedCarIsValid()
            }
            .onChange(of: selectedCarID) { _, newValue in
                applyDefaultMileageIfNeeded(for: newValue)
            }
            .onChange(of: focusedField) { _, newValue in
                guard newValue == .cost else { return }
                guard !isCostReadOnly else { return }
                guard cost == "0" else { return }
                cost = ""
            }
            .onChange(of: cost) { _, newValue in
                cost = sanitizeCostInput(newValue)
            }
            .onChange(of: isSplitEditMode) { _, newValue in
                if newValue {
                    if hasInitializedSplitDraft == false {
                        cost = "0"
                        note = ""
                        hasInitializedSplitDraft = true
                    }
                } else {
                    hasInitializedSplitDraft = false
                }
            }
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
            .navigationDestination(isPresented: $isIntervalConfirmPresented) {
                intervalConfirmSheet
            }
            .alert(AppAlertText.duplicateCycleTitle, isPresented: $isDuplicateCycleAlertPresented) {
                Button(AppPopupText.goEdit) {
                    openDuplicateCycleRecordEditor()
                }
                Button(AppPopupText.cancel, role: .cancel) {}
            } message: {
                Text(duplicateCycleAlertMessage)
            }
            .alert(AppAlertText.saveFailedTitle, isPresented: Binding(
                get: { editingRecord != nil && isSaveErrorAlertPresented },
                set: { isSaveErrorAlertPresented = $0 }
            )) {
                Button(AppPopupText.acknowledge, role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
    }

    /// 输入“总费用/备注”时给表单底部增加占位，避免键盘遮住当前输入行。
    private var inputAvoidanceBottomInset: CGFloat {
        isAnyInputActive ? 120 : 0
    }

    private var addRecordForm: some View {
        Form {
            Section("车辆信息") {
                if availableCars.isEmpty {
                    Text("请先添加车辆，再记录保养。")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("车辆")
                        Spacer()
                        Text(selectedCarDisplayText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("保养时间")
                        Spacer()
                        Button {
                            presentPickerSheet(.serviceDate)
                        } label: {
                            rowValueActionLabel(text: AppDateContext.formatShortDate(maintenanceDate))
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
                                    wan: mileageWan,
                                    qian: mileageQian,
                                    bai: mileageBai
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("保养项目") {
                if isItemSelectionLocked {
                    HStack {
                        Text("选择项目")
                        Spacer()
                        Text(lockedItemNameText)
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
                            Text(selectedItemsText)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }
            }

            if !isCostReadOnly {
                Section("保养费用") {
                    HStack {
                        Text("总费用")
                        Spacer()
                        TextField("请输入", text: $cost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .cost)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = .cost
                    }

                    TextField("备注（选填）", text: $note)
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

extension AddMaintenanceRecordView {
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
