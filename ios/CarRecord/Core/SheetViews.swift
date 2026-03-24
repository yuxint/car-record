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

    private var hasDraftChanges: Bool {
        draftWan != wan || draftQian != qian || draftBai != bai
    }

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
                    Button(AppPopupText.cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppPopupText.confirm) {
                        wan = draftWan
                        qian = draftQian
                        bai = draftBai
                        onConfirm()
                    }
                    .disabled(hasDraftChanges == false)
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationBackground(Color(.systemBackground))
    }
}

/// 通用日期选择弹窗：统一图形化日期选择和"选择即应用"的行为。
struct DayDatePickerSheetView: View {
    let title: String
    let label: String
    let currentDate: Date
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
        self.currentDate = currentDate
        _draftDate = State(initialValue: currentDate)
        self.onApply = onApply
        self.onCancel = onCancel
    }

    private var hasDraftChanges: Bool {
        let calendar = Calendar.current
        let draftDay = calendar.startOfDay(for: draftDate)
        let currentDay = calendar.startOfDay(for: currentDate)
        return draftDay != currentDay
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(label, selection: $draftDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppPopupText.cancel) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppPopupText.confirm) {
                        onApply(draftDate)
                    }
                    .disabled(hasDraftChanges == false)
                }
            }
            .scrollDisabled(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }
}

/// 通用锚点下拉多选组件：点击触发器后在其下方展示浮层，支持连续多选与手动完成。
struct AnchoredMultiSelectDropdown<Option: Identifiable>: View where Option.ID: Hashable {
    let options: [Option]
    @Binding private var selections: Set<Option.ID>
    let emptyText: String
    let summaryText: (Int) -> String
    let optionTitle: (Option) -> String

    @State private var isExpanded = false
    @State private var triggerSize: CGSize = .zero

    init(
        options: [Option],
        selections: Binding<Set<Option.ID>>,
        emptyText: String,
        summaryText: @escaping (Int) -> String,
        optionTitle: @escaping (Option) -> String
    ) {
        self.options = options
        _selections = selections
        self.emptyText = emptyText
        self.summaryText = summaryText
        self.optionTitle = optionTitle
    }

    private var chevron: some View {
        Image(systemName: "chevron.up.chevron.down")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private var labelText: String {
        selections.isEmpty ? emptyText : summaryText(selections.count)
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(labelText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                chevron
            }
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        triggerSize = proxy.size
                    }
                    .onChange(of: proxy.size) { _, newValue in
                        triggerSize = newValue
                    }
            }
        )
        .overlay(alignment: .topTrailing) {
            if isExpanded {
                dropdownPanel
                    .offset(y: triggerSize.height + 8)
                    .zIndex(20)
            }
        }
    }

    private var dropdownPanel: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(options) { option in
                        Button {
                            toggleSelection(option.id)
                        } label: {
                            HStack(spacing: 8) {
                                Text(optionTitle(option))
                                    .lineLimit(1)
                                Spacer()
                                if selections.contains(option.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if option.id != options.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 220)

            Divider()

            Button(AppPopupText.done) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded = false
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .frame(width: max(triggerSize.width, 220))
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private func toggleSelection(_ id: Option.ID) {
        if selections.contains(id) {
            selections.remove(id)
        } else {
            selections.insert(id)
        }
    }
}
