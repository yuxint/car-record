import SwiftUI

/// 通用里程三段选择弹窗：统一“万/千/百”交互与工具栏行为。
struct MileagePickerSheetView: View {
    let title: String
    @Binding private var wan: Int
    @Binding private var qian: Int
    @Binding private var bai: Int
    @State private var draftWan: Int
    @State private var draftQian: Int
    @State private var draftBai: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    init(
        title: String,
        wan: Binding<Int>,
        qian: Binding<Int>,
        bai: Binding<Int>,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        _wan = wan
        _qian = qian
        _bai = bai
        _draftWan = State(initialValue: wan.wrappedValue)
        _draftQian = State(initialValue: qian.wrappedValue)
        _draftBai = State(initialValue: bai.wrappedValue)
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("万", selection: $draftWan) {
                    ForEach(0...99, id: \.self) { value in
                        Text("\(value)万").tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("千", selection: $draftQian) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)千").tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("百", selection: $draftBai) {
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
                    Button("确认") {
                        wan = draftWan
                        qian = draftQian
                        bai = draftBai
                        onConfirm()
                    }
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
    @State private var draftDate: Date
    let onApply: (Date) -> Void
    let onCancel: () -> Void

    init(
        title: String,
        label: String,
        currentDate: Date,
        onApply: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.label = label
        _draftDate = State(initialValue: currentDate)
        self.onApply = onApply
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(label, selection: $draftDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
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
        .presentationDetents([.medium]) // HIG 推荐的适中高度
        .presentationDragIndicator(.visible)
    }
}
