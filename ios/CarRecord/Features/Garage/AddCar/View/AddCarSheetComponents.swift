import SwiftUI
import SwiftData

extension AddCarView {
    @ViewBuilder
    var mileagePickerSheet: some View {
        MileagePickerSheetView(
            title: "选择里程",
            wan: $viewModel.mileageWan,
            qian: $viewModel.mileageQian,
            bai: $viewModel.mileageBai,
            onCancel: { isMileagePickerPresented = false },
            onConfirm: { isMileagePickerPresented = false }
        )
    }

    @ViewBuilder
    var onRoadDatePickerSheet: some View {
        DayDatePickerSheetView(
            title: "选择上路日期",
            label: "上路日期",
            currentDate: viewModel.onRoadDate,
            onApply: { newValue in
                viewModel.onRoadDate = newValue
                isOnRoadDatePickerPresented = false
            },
            onCancel: { isOnRoadDatePickerPresented = false }
        )
    }

    /// 项目设置页：统一编辑名称与提醒方式。
    @ViewBuilder
    func maintenanceDraftEditorPage(
        title: String,
        draft: Binding<MaintenanceItemDraft>,
        canEditName: Bool,
        onDelete: (() -> Void)?,
        onRestoreDefaults: (() -> Void)?,
        canRestoreDefaults: Bool,
        confirmButtonTitle: String,
        isConfirmButtonEnabled: Bool,
        onSave: @escaping () -> Void,
        validationMessage: String,
        isValidationAlertPresented: Binding<Bool>
    ) -> some View {
        Form {
            Section("项目名称") {
                if canEditName {
                    TextField("请输入项目名称", text: draft.name)
                } else {
                    Text(draft.wrappedValue.name)
                        .foregroundStyle(.secondary)
                }
            }

            Section("提醒方式") {
                Toggle("按里程提醒", isOn: draft.remindByMileage)
                if draft.wrappedValue.remindByMileage {
                    Stepper(
                        value: draft.mileageInterval,
                        in: 1000...100_000,
                        step: 1000
                    ) {
                        Text("里程间隔：\(MileageDisplayFormatter.reminderDistanceText(for: draft.wrappedValue.mileageInterval))")
                    }
                }

                Toggle("按时间提醒", isOn: draft.remindByTime)
                if draft.wrappedValue.remindByTime {
                    Stepper(
                        value: viewModel.monthIntervalYearBinding(for: draft),
                        in: 0.5...10,
                        step: 0.5
                    ) {
                        Text("时间间隔：\(viewModel.yearIntervalText(from: draft.wrappedValue.monthInterval))年")
                    }
                }
            }

            if let onRestoreDefaults {
                Section {
                    Button("恢复默认值") {
                        onRestoreDefaults()
                    }
                    .disabled(canRestoreDefaults == false)
                }
            }

            if let onDelete {
                Section {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text("删除该项目")
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(confirmButtonTitle) {
                    onSave()
                }
                .disabled(isConfirmButtonEnabled == false)
            }
        }
        .alert(AppAlertText.promptTitle, isPresented: isValidationAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }
}
