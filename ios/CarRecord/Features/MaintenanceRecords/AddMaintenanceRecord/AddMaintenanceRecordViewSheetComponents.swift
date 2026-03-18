import SwiftUI
import SwiftData
import UIKit

extension AddMaintenanceRecordView {
    @ViewBuilder
    var maintenanceDatePickerSheet: some View {
        DayDatePickerSheetView(
            title: "选择保养时间",
            label: "保养时间",
            draftDate: $draftMaintenanceDate,
            currentDate: maintenanceDate,
            onApply: { newValue in
                maintenanceDate = newValue
                activePickerSheet = nil
            },
            onCancel: { activePickerSheet = nil }
        )
    }

    @ViewBuilder
    var mileagePickerSheet: some View {
        MileagePickerSheetView(
            title: "选择当前里程",
            wan: $mileageWan,
            qian: $mileageQian,
            bai: $mileageBai,
            onCancel: { activePickerSheet = nil },
            onConfirm: { activePickerSheet = nil }
        )
    }

    @ViewBuilder
    var maintenanceItemsPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(availableItemOptions) { option in
                    Button {
                        toggleItem(option.id)
                    } label: {
                        HStack {
                            Text(option.name)
                            Spacer()
                            if selectedItems.contains(option.id) {
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
                    Button("完成") {
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
                Text("请确认本次保养项目的下次提醒间隔，点击保存后会同时保存保养记录与默认提醒值。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(intervalConfirmDrafts.indices, id: \.self) { index in
                Section(intervalConfirmDrafts[index].name) {
                    if intervalConfirmDrafts[index].remindByMileage {
                        Stepper(value: $intervalConfirmDrafts[index].mileageInterval, in: 1_000...100_000, step: 500) {
                            Text("下次里程间隔：\(intervalConfirmDrafts[index].mileageInterval) km")
                        }
                    }

                    if intervalConfirmDrafts[index].remindByTime {
                        Stepper(value: $intervalConfirmDrafts[index].yearInterval, in: 0.5...10, step: 0.5) {
                            Text("下次时间间隔：\(formattedYearInterval(intervalConfirmDrafts[index].yearInterval))年")
                        }
                    }

                    if intervalConfirmDrafts[index].remindByMileage == false &&
                        intervalConfirmDrafts[index].remindByTime == false {
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
                    isIntervalConfirmPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    applyIntervalConfirmationAndDismiss()
                }
            }
        }
    }

}
