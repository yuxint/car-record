import SwiftUI
import SwiftData

/// 新增/编辑车辆页：全部使用选择器，避免唤醒系统输入法。
struct AddCarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let editingCar: Car?

    @State private var brand: String
    @State private var modelName: String
    @State private var mileageWan: Int
    @State private var mileageQian: Int
    @State private var onRoadDate: Date
    @State private var draftOnRoadDate: Date
    @State private var activePickerSheet: CarPickerSheet?

    /// 固定品牌选项：仅支持东风本田。
    private let fixedBrandOptions = [
        "东风本田",
    ]

    /// 固定车型选项：仅支持思域。
    private let fixedModelOptions = [
        "思域",
    ]

    init(editingCar: Car? = nil) {
        self.editingCar = editingCar

        /// 在初始化阶段回填编辑数据，避免首次打开编辑页时状态晚于界面渲染。
        if let editingCar {
            let segments = MileageSegmentFormatter.segments(from: editingCar.mileage)
            _brand = State(initialValue: "东风本田")
            _modelName = State(initialValue: "思域")
            _mileageWan = State(initialValue: segments.wan)
            _mileageQian = State(initialValue: segments.qian)
            _onRoadDate = State(initialValue: editingCar.purchaseDate)
            _draftOnRoadDate = State(initialValue: editingCar.purchaseDate)
        } else {
            let now = Date.now
            _brand = State(initialValue: "东风本田")
            _modelName = State(initialValue: "思域")
            _mileageWan = State(initialValue: 0)
            _mileageQian = State(initialValue: 0)
            _onRoadDate = State(initialValue: now)
            _draftOnRoadDate = State(initialValue: now)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("车辆信息") {
                    Picker("品牌", selection: $brand) {
                        ForEach(fixedBrandOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }

                    Picker("车型", selection: $modelName) {
                        ForEach(fixedModelOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("当前里程") {
                    Button {
                        presentPickerSheet(.mileage)
                    } label: {
                        HStack {
                            Text("里程（公里）")
                            Spacer()
                            Text("\(mileageWan)万 \(mileageQian)千")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section("上路信息") {
                    Button {
                        draftOnRoadDate = onRoadDate
                        presentPickerSheet(.onRoadDate)
                    } label: {
                        HStack {
                            Text("上路日期")
                            Spacer()
                            Text(DateTextFormatter.shortDate(onRoadDate))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Text("车龄：\(CarAgeFormatter.yearsText(from: onRoadDate)) 年")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(editingCar == nil ? "添加车辆" : "编辑车辆")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCar()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(item: $activePickerSheet) { sheet in
                switch sheet {
                case .mileage:
                    mileagePickerSheet
                case .onRoadDate:
                    onRoadDatePickerSheet
                }
            }
        }
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
            .navigationTitle("选择里程")
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
    private var onRoadDatePickerSheet: some View {
        NavigationStack {
            DatePicker("上路日期", selection: $draftOnRoadDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle("选择上路日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            draftOnRoadDate = onRoadDate
                            activePickerSheet = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            onRoadDate = draftOnRoadDate
                            activePickerSheet = nil
                        }
                    }
                }
        }
        .presentationDetents([.height(300)])
    }

    /// 合并“万 + 千”两段，得到实际公里数。
    private var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian)
    }

    /// 基础表单校验：防止空值和非法里程进入本地数据库。
    private var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 保存车辆并立即持久化。
    private func saveCar() {
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingCar {
            editingCar.brand = normalizedBrand
            editingCar.modelName = normalizedModelName
            editingCar.mileage = currentMileage
            editingCar.purchaseDate = onRoadDate
        } else {
            let car = Car(
                brand: normalizedBrand,
                modelName: normalizedModelName,
                mileage: currentMileage,
                purchaseDate: onRoadDate
            )
            modelContext.insert(car)
        }

        try? modelContext.save()
        dismiss()
    }

    /// 统一拉起弹窗：规避首次进入页面时按钮点击偶发失效的问题。
    private func presentPickerSheet(_ sheet: CarPickerSheet) {
        DispatchQueue.main.async {
            activePickerSheet = sheet
        }
    }
}

/// 新增/编辑车辆页可拉起的弹窗类型。
private enum CarPickerSheet: Identifiable {
    case mileage
    case onRoadDate

    var id: String {
        switch self {
        case .mileage:
            return "mileage"
        case .onRoadDate:
            return "onRoadDate"
        }
    }
}
