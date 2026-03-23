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
            onCancel: { viewModel.activePickerSheet = nil },
            onConfirm: { viewModel.activePickerSheet = nil }
        )
    }

    @ViewBuilder
    var onRoadDatePickerSheet: some View {
        DayDatePickerSheetView(
            title: "选择上路日期",
            label: "上路日期",
            draftDate: $viewModel.draftOnRoadDate,
            currentDate: viewModel.onRoadDate,
            onApply: { newValue in
                viewModel.onRoadDate = newValue
                viewModel.activePickerSheet = nil
            },
            onCancel: { viewModel.activePickerSheet = nil }
        )
    }

    /// 项目设置弹窗：统一编辑名称、提醒方式和阈值。
    @ViewBuilder
    func maintenanceDraftEditorSheet(
        title: String,
        draft: Binding<MaintenanceItemDraft>,
        canEditName: Bool,
        onDelete: (() -> Void)?,
        onSave: @escaping () -> Void
    ) -> some View {
        NavigationStack {
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
                            step: 500
                        ) {
                            Text("里程间隔：\(draft.wrappedValue.mileageInterval) km")
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

                Section("进度颜色阈值（%）") {
                    Stepper(value: draft.warningStartPercent, in: 50...300, step: 5) {
                        Text("黄色阈值：\(draft.wrappedValue.warningStartPercent)%")
                    }
                    Stepper(value: draft.dangerStartPercent, in: 55...400, step: 5) {
                        Text("红色阈值：\(draft.wrappedValue.dangerStartPercent)%")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.draftSheetTarget = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                    }
                }
            }
            .onChange(of: draft.wrappedValue.warningStartPercent) { _, newValue in
                if draft.wrappedValue.dangerStartPercent <= newValue {
                    draft.wrappedValue.dangerStartPercent = newValue + 5
                }
            }
        }
    }
}
