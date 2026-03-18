import SwiftUI

/// 通用里程三段选择弹窗：统一“万/千/百”交互与工具栏行为。
struct MileagePickerSheetView: View {
    let title: String
    @Binding var wan: Int
    @Binding var qian: Int
    @Binding var bai: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("万", selection: $wan) {
                    ForEach(0...99, id: \.self) { value in
                        Text("\(value)万").tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("千", selection: $qian) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)千").tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("百", selection: $bai) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)百").tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认", action: onConfirm)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

/// 通用日期选择弹窗：统一图形化日期选择和"选择即应用"的行为。
struct DayDatePickerSheetView: View {
    let title: String
    let label: String
    @Binding var draftDate: Date
    let currentDate: Date
    let onApply: (Date) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(label, selection: $draftDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
            .padding(.top, 4)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        draftDate = currentDate
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        onApply(draftDate)
                    }
                }
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }
}
