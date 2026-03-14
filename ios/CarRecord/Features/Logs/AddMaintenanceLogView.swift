import SwiftUI
import SwiftData
import UIKit

/// 新增/编辑保养页：支持下拉多选项目、自定义项目、保养时间和里程弹窗选择。
struct AddMaintenanceLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Car.purchaseDate, order: .reverse) private var cars: [Car]
    @Query(sort: \MaintenanceLog.date, order: .reverse) private var maintenanceLogs: [MaintenanceLog]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]

    let editingLog: MaintenanceLog?

    @State private var selectedCarID: UUID?
    @State private var selectedItems = Set<String>()
    @State private var maintenanceDate = Date.now
    @State private var draftMaintenanceDate = Date.now
    @State private var cost = ""
    @State private var mileageWan = 0
    @State private var mileageQian = 0
    @State private var note = ""
    @State private var hasLoadedInitialValues = false
    @State private var activePickerSheet: MaintenancePickerSheet?
    @FocusState private var focusedField: FocusField?

    init(editingLog: MaintenanceLog? = nil) {
        self.editingLog = editingLog
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("车辆信息") {
                    if cars.isEmpty {
                        Text("请先添加车辆，再记录保养。")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("车辆", selection: $selectedCarID) {
                            ForEach(cars) { car in
                                Text("\(car.brand) \(car.modelName)（\(DateTextFormatter.shortDate(car.purchaseDate))）")
                                    .tag(Optional(car.id))
                            }
                        }
                    }

                    Button {
                        draftMaintenanceDate = maintenanceDate
                        presentPickerSheet(.maintenanceDate)
                    } label: {
                        HStack {
                            Text("保养时间")
                            Spacer()
                            Text(DateTextFormatter.shortDate(maintenanceDate))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentPickerSheet(.mileage)
                    } label: {
                        HStack {
                            Text("当前里程（公里）")
                            Spacer()
                            Text("\(mileageWan)万 \(mileageQian)千")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section("保养项目") {
                    Button {
                        presentPickerSheet(.maintenanceItems)
                    } label: {
                        HStack {
                            Text("选择项目（可多选）")
                            Spacer()
                            Text(selectedItemsText)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

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
            .navigationTitle(editingLog == nil ? "新增保养" : "编辑保养")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isAnyInputActive {
                        Button("保存") {
                            saveLog()
                        }
                        .disabled(!canSave)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .cost {
                        Spacer()
                        Button("保存") {
                            closeInputEditors()
                        }
                    }
                }
            }
            .onAppear {
                loadInitialValuesIfNeeded()
            }
            .onChange(of: selectedCarID) { _, newValue in
                applyDefaultMileageIfNeeded(for: newValue)
            }
            .onChange(of: cost) { _, newValue in
                cost = sanitizeCostInput(newValue)
            }
            .sheet(item: $activePickerSheet) { sheet in
                switch sheet {
                case .maintenanceDate:
                    maintenanceDatePickerSheet
                case .mileage:
                    mileagePickerSheet
                case .maintenanceItems:
                    maintenanceItemsPickerSheet
                }
            }
        }
    }

    @ViewBuilder
    private var maintenanceDatePickerSheet: some View {
        NavigationStack {
            DatePicker("保养时间", selection: $draftMaintenanceDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle("选择保养时间")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            draftMaintenanceDate = maintenanceDate
                            activePickerSheet = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            maintenanceDate = draftMaintenanceDate
                            activePickerSheet = nil
                        }
                    }
                }
        }
        .presentationDetents([.height(300)])
    }

    @ViewBuilder
    private var mileagePickerSheet: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("万", selection: $mileageWan) {
                    ForEach(0...99, id: \.self) { value in
                        Text("\(value)万").tag(value)
                    }
                }
                .pickerStyle(.wheel)

                Picker("千", selection: $mileageQian) {
                    ForEach(0...9, id: \.self) { value in
                        Text("\(value)千").tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("选择当前里程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        activePickerSheet = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        activePickerSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }

    @ViewBuilder
    private var maintenanceItemsPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(availableItemNames, id: \.self) { item in
                    Button {
                        toggleItem(item)
                    } label: {
                        HStack {
                            Text(item)
                            Spacer()
                            if selectedItems.contains(item) {
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

    /// 合并“万 + 千”两段，得到保养发生时的公里数。
    private var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian)
    }

    /// 可选项目列表：默认项优先，已选但不在配置中的旧项目兜底保留。
    private var availableItemNames: [String] {
        let sortedNames = maintenanceItemOptions
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault {
                    return lhs.isDefault && !rhs.isDefault
                }
                return lhs.createdAt < rhs.createdAt
            }
            .map(\.name)

        let missingSelected = selectedItems.filter { !sortedNames.contains($0) }
        return sortedNames + missingSelected.sorted()
    }

    private var selectedItemsText: String {
        selectedItems.isEmpty ? "请选择" : "已选\(selectedItems.count)项"
    }

    /// 合法费用：非负，最多 2 位小数。
    private var parsedCost: Double? {
        guard !cost.isEmpty, let value = Double(cost), value >= 0 else { return nil }
        return value
    }

    /// 基础输入校验，避免非法数据入库。
    private var canSave: Bool {
        selectedCarID != nil &&
        !selectedItems.isEmpty &&
        parsedCost != nil
    }

    /// 当前是否处于任意输入态：用于避免导航栏“保存”与键盘操作冲突。
    private var isAnyInputActive: Bool {
        focusedField != nil
    }

    /// 根据选择的车辆写入保养记录，并立即保存到本地。
    private func saveLog() {
        guard
            let selectedCarID,
            let selectedCar = cars.first(where: { $0.id == selectedCarID }),
            let parsedCost
        else {
            return
        }

        /// 按当前项目列表顺序落库，保证展示稳定。
        let orderedItems = availableItemNames.filter { selectedItems.contains($0) }
        let title = MaintenanceItemCatalog.join(orderedItems)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingLog {
            editingLog.date = maintenanceDate
            editingLog.title = title
            editingLog.cost = parsedCost
            editingLog.mileage = currentMileage
            editingLog.note = normalizedNote
            editingLog.car = selectedCar
        } else {
            let log = MaintenanceLog(
                date: maintenanceDate,
                title: title,
                cost: parsedCost,
                mileage: currentMileage,
                note: normalizedNote,
                car: selectedCar
            )
            modelContext.insert(log)
        }

        /// 当保养日期是今天时，自动同步车辆当前里程。
        if Calendar.current.isDateInToday(maintenanceDate) {
            selectedCar.mileage = currentMileage
        }

        try? modelContext.save()
        dismiss()
    }

    /// 编辑场景回填原值，新增场景则选中第一辆车。
    private func loadInitialValuesIfNeeded() {
        guard !hasLoadedInitialValues else { return }
        hasLoadedInitialValues = true

        MaintenanceItemCatalog.ensureDefaults(in: modelContext)

        if let editingLog {
            selectedCarID = editingLog.car?.id ?? cars.first?.id
            selectedItems = Set(MaintenanceItemCatalog.parse(editingLog.title))
            maintenanceDate = editingLog.date
            draftMaintenanceDate = editingLog.date
            cost = formatCost(editingLog.cost)
            let segments = MileageSegmentFormatter.segments(from: editingLog.mileage)
            mileageWan = segments.wan
            mileageQian = segments.qian
            note = editingLog.note
            return
        }

        selectedCarID = cars.first?.id
        draftMaintenanceDate = maintenanceDate
        applyDefaultMileageIfNeeded(for: selectedCarID)
    }

    /// 切换多选项状态。
    private func toggleItem(_ item: String) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }

    /// 过滤非法字符并限制 2 位小数。
    private func sanitizeCostInput(_ raw: String) -> String {
        let filtered = raw.filter { $0.isNumber || $0 == "." }
        if filtered.isEmpty { return "" }

        var result = ""
        var hasDot = false
        var fractionCount = 0

        for char in filtered {
            if char == "." {
                if hasDot { continue }
                hasDot = true
                if result.isEmpty { result = "0" }
                result.append(char)
                continue
            }

            if hasDot {
                if fractionCount >= 2 { continue }
                fractionCount += 1
            }
            result.append(char)
        }

        return result
    }

    /// 编辑态费用展示：最多两位小数，去掉无效尾零。
    private func formatCost(_ value: Double) -> String {
        if value == 0 { return "0" }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }

    /// 新增场景默认里程：优先取该车最近一次保养里程，无记录则为 0。
    private func applyDefaultMileageIfNeeded(for carID: UUID?) {
        guard editingLog == nil else { return }

        guard let carID else {
            mileageWan = 0
            mileageQian = 0
            return
        }

        let lastMileage = maintenanceLogs.first(where: { $0.car?.id == carID })?.mileage ?? 0
        let segments = MileageSegmentFormatter.segments(from: lastMileage)
        mileageWan = segments.wan
        mileageQian = segments.qian
    }

    /// 统一拉起弹窗：先收起键盘，避免出现“要点几次才弹出”的交互问题。
    private func presentPickerSheet(_ sheet: MaintenancePickerSheet) {
        closeInputEditors()
        DispatchQueue.main.async {
            activePickerSheet = sheet
        }
    }

    /// 统一收起当前输入态：用于弹窗切换和键盘右上角“保存”按钮。
    private func closeInputEditors() {
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
}

/// 当前页面内需要拉起的弹窗类型。
private enum MaintenancePickerSheet: Identifiable {
    case maintenanceDate
    case mileage
    case maintenanceItems

    var id: String {
        switch self {
        case .maintenanceDate:
            return "maintenanceDate"
        case .mileage:
            return "mileage"
        case .maintenanceItems:
            return "maintenanceItems"
        }
    }
}

/// 输入焦点：用于区分当前是“总费用”还是“备注”在编辑。
private enum FocusField {
    case cost
    case note
}
