import SwiftUI

extension AddMaintenanceRecordView {
    @ViewBuilder
    var maintenanceDatePickerSheet: some View {
        DayDatePickerSheetView(
            title: "选择保养时间",
            label: "保养时间",
            currentDate: viewModel.maintenanceDate,
            onApply: { newValue in
                viewModel.maintenanceDate = newValue
                activePickerSheet = nil
            },
            onCancel: { activePickerSheet = nil }
        )
    }

    @ViewBuilder
    var mileagePickerSheet: some View {
        MileagePickerSheetView(
            title: "选择当前里程",
            wan: $viewModel.mileageWan,
            qian: $viewModel.mileageQian,
            bai: $viewModel.mileageBai,
            onCancel: { activePickerSheet = nil },
            onConfirm: { activePickerSheet = nil }
        )
    }

    @ViewBuilder
    var maintenanceItemsPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(viewModel.availableItemOptions) { option in
                    Button {
                        viewModel.toggleItem(option.id)
                    } label: {
                        HStack {
                            Text(option.name)
                            Spacer()
                            if viewModel.selectedItems.contains(option.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("选择保养项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppPopupText.done) {
                        activePickerSheet = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    var intervalConfirmSheet: some View {
        Form {
            Section {
                Text(viewModel.intervalConfirmIntroductionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.intervalConfirmDrafts.indices, id: \.self) { index in
                Section(viewModel.intervalConfirmDrafts[index].name) {
                    if viewModel.intervalConfirmDrafts[index].remindByMileage {
                        Stepper(value: $viewModel.intervalConfirmDrafts[index].mileageInterval, in: 1_000...100_000, step: 500) {
                            Text("下次里程间隔：\(viewModel.intervalConfirmDrafts[index].mileageInterval) km")
                        }
                    }

                    if viewModel.intervalConfirmDrafts[index].remindByTime {
                        Stepper(value: $viewModel.intervalConfirmDrafts[index].yearInterval, in: 0.5...10, step: 0.5) {
                            Text("下次时间间隔：\(viewModel.formattedYearInterval(viewModel.intervalConfirmDrafts[index].yearInterval))年")
                        }
                    }

                    if viewModel.intervalConfirmDrafts[index].remindByMileage == false &&
                        viewModel.intervalConfirmDrafts[index].remindByTime == false {
                        Text("该项目未开启提醒方式。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("确认下次间隔")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("返回") {
                    viewModel.isIntervalConfirmPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    closeInputEditors()
                    viewModel.applyIntervalConfirmationAndDismiss(
                        modelContext: modelContext,
                        dismiss: dismiss.callAsFunction
                    )
                }
            }
        }
        .alert(AppAlertText.duplicateCycleTitle, isPresented: $viewModel.isIntervalConfirmDuplicateCycleAlertPresented) {
            Button(AppPopupText.goEdit) {
                viewModel.openDuplicateCycleRecordEditor()
            }
            Button(AppPopupText.cancel, role: .cancel) {}
        } message: {
            Text(viewModel.duplicateCycleAlertMessage)
        }
        .alert(AppAlertText.saveFailedTitle, isPresented: $viewModel.isIntervalConfirmSaveErrorAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(viewModel.saveErrorMessage)
        }
    }
}
