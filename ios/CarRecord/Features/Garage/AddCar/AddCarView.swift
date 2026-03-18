import SwiftUI
import SwiftData

/// 新增/编辑车辆页：全部使用选择器，避免唤醒系统输入法。
struct AddCarView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) var cars: [Car]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) var maintenanceItemOptions: [MaintenanceItemOption]

    let editingCar: Car?

    @State var brand: String
    @State var modelName: String
    @State var mileageWan: Int
    @State var mileageQian: Int
    @State var mileageBai: Int
    @State var onRoadDate: Date
    @State var draftOnRoadDate: Date
    @State var activePickerSheet: CarPickerSheet?
    @State var itemDrafts: [MaintenanceItemDraft] = []
    @State var existingItemDrafts: [MaintenanceItemDraft] = []
    @State var customDraft = MaintenanceItemDraft.defaultDraft(name: "自定义项目")
    @State var draftSheetTarget: MaintenanceDraftSheetTarget?
    @State var saveErrorMessage = ""
    @State var isSaveErrorAlertPresented = false
    @State var validationMessage = ""
    @State var isValidationAlertPresented = false

    /// 固定品牌选项：先限制为小范围，后续按业务扩展。
    private static let fixedBrandOptions = [
        "本田",
        "日产",
    ]

    /// 车型选项：按品牌返回对应车型列表。
    private static func modelOptions(for brand: String) -> [String] {
        switch brand {
        case "本田":
            return ["22款思域", "23款CR-V", "24款雅阁"]
        case "日产":
            return ["22款轩逸", "23款奇骏", "24款天籁"]
        default:
            return ["22款思域"]
        }
    }

    /// 标准化品牌名称，去除空格和换行符。
    private static func normalizedBrand(_ brand: String) -> String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 标准化车型名称，去除空格和换行符。
    private static func normalizedModel(brand: String, model: String) -> String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(editingCar: Car? = nil) {
        self.editingCar = editingCar

        /// 在初始化阶段回填编辑数据，避免首次打开编辑页时状态晚于界面渲染。
        if let editingCar {
            let segments = MileageSegmentFormatter.segments(from: editingCar.mileage)
            let normalizedBrand = Self.normalizedBrand(editingCar.brand)
            let normalizedModel = Self.normalizedModel(brand: normalizedBrand, model: editingCar.modelName)
            _brand = State(initialValue: normalizedBrand)
            _modelName = State(initialValue: normalizedModel)
            _mileageWan = State(initialValue: segments.wan)
            _mileageQian = State(initialValue: segments.qian)
            _mileageBai = State(initialValue: segments.bai)
            _onRoadDate = State(initialValue: editingCar.purchaseDate)
            _draftOnRoadDate = State(initialValue: editingCar.purchaseDate)
        } else {
            let now = AppDateContext.now()
            _brand = State(initialValue: Self.fixedBrandOptions.first ?? "本田")
            _modelName = State(initialValue: Self.modelOptions(for: Self.fixedBrandOptions.first ?? "本田").first ?? "22款思域")
            _mileageWan = State(initialValue: 0)
            _mileageQian = State(initialValue: 0)
            _mileageBai = State(initialValue: 0)
            _onRoadDate = State(initialValue: now)
            _draftOnRoadDate = State(initialValue: now)
        }
    }

    var body: some View {
        NavigationStack {
            addCarForm
        }
    }

    private var addCarForm: some View {
        Form {
            vehicleSection
            mileageSection
            onRoadSection
            maintenanceItemsSection
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
        .onChange(of: brand) { _, newValue in
            let options = Self.modelOptions(for: newValue)
            if options.contains(modelName) == false {
                modelName = options.first ?? ""
            }
            rebuildItemDraftsForCurrentModel()
        }
        .onChange(of: modelName) { _, _ in
            rebuildItemDraftsForCurrentModel()
        }
        .onAppear {
            rebuildItemDraftsForCurrentModel()
            rebuildExistingDraftsFromOptions()
        }
        .onChange(of: maintenanceItemOptions.map(\.id)) { _, _ in
            rebuildExistingDraftsFromOptions()
        }
        .alert("保存失败", isPresented: $isSaveErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .alert("提示", isPresented: $isValidationAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .sheet(item: $draftSheetTarget) { target in
            draftEditorSheet(target: target)
        }
    }

    private var vehicleSection: some View {
        Section("车辆信息") {
            Picker("品牌", selection: $brand) {
                ForEach(Self.fixedBrandOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }

            Picker("车型", selection: $modelName) {
                ForEach(Self.modelOptions(for: brand), id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        }
    }

    private var mileageSection: some View {
        Section("当前里程") {
            Button {
                presentPickerSheet(.mileage)
            } label: {
                HStack {
                    Text("里程")
                    Spacer()
                    Text(MileageSegmentFormatter.text(wan: mileageWan, qian: mileageQian, bai: mileageBai))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var onRoadSection: some View {
        Section("上路信息") {
            Button {
                draftOnRoadDate = onRoadDate
                presentPickerSheet(.onRoadDate)
            } label: {
                HStack {
                    Text("上路日期")
                    Spacer()
                    Text(AppDateContext.formatShortDate(onRoadDate))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("车龄：\(CarAgeFormatter.yearsText(from: onRoadDate, now: AppDateContext.now())) 年")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var maintenanceItemsSection: some View {
        Section("保养项目设置") {
            if maintenanceItemOptions.isEmpty {
                ForEach(itemDrafts) { draft in
                    draftRow(draft)
                }

                Button {
                    customDraft = MaintenanceItemDraft.defaultDraft(name: "自定义项目")
                    draftSheetTarget = .addCustom
                } label: {
                    Label("新增自定义项目", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)

                Text("可按需关闭项目，也可点项目进入设置里程/时间提醒规则与阈值。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(existingItemDrafts) { draft in
                    existingDraftRow(draft)
                }

                Text("点任一项目可直接修改名称、提醒规则和阈值；与新增车辆页保持一致。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func draftRow(_ draft: MaintenanceItemDraft) -> some View {
        HStack(spacing: 12) {
            Button {
                draftSheetTarget = .edit(draft.id)
            } label: {
                draftSummary(draft)
            }
            .buttonStyle(.plain)

            Toggle("", isOn: draftEnabledBinding(id: draft.id))
                .labelsHidden()
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if draft.isDefault == false {
                Button(role: .destructive) {
                    removeCustomDraft(draft.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    private func existingDraftRow(_ draft: MaintenanceItemDraft) -> some View {
        HStack(spacing: 8) {
            Button {
                draftSheetTarget = .editExisting(draft.id)
            } label: {
                draftSummary(draft)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func draftSummary(_ draft: MaintenanceItemDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(draft.name)
                    .lineLimit(1)
                Text(draft.isDefault ? "默认" : "自定义")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            Text("提醒：\(MaintenanceItemDraft.reminderSummary(for: draft))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func draftEditorSheet(target: MaintenanceDraftSheetTarget) -> some View {
        switch target {
        case .edit(let draftID):
            if let draftBinding = draftBinding(id: draftID) {
                maintenanceDraftEditorSheet(
                    title: "保养项目设置",
                    draft: draftBinding,
                    canEditName: draftBinding.wrappedValue.isDefault == false,
                    onDelete: draftBinding.wrappedValue.isDefault ? nil : {
                        removeCustomDraft(draftID)
                        draftSheetTarget = nil
                    },
                    onSave: {
                        let draft = draftBinding.wrappedValue
                        guard validateDraft(draft, excludingID: draft.id) else { return }
                        draftSheetTarget = nil
                    }
                )
            }
        case .addCustom:
            maintenanceDraftEditorSheet(
                title: "新增自定义项目",
                draft: $customDraft,
                canEditName: true,
                onDelete: nil,
                onSave: {
                    guard validateDraft(customDraft, excludingID: nil) else { return }
                    itemDrafts.append(customDraft)
                    draftSheetTarget = nil
                }
            )
        case .editExisting(let optionID):
            if let draftBinding = existingDraftBinding(optionID: optionID) {
                maintenanceDraftEditorSheet(
                    title: "保养项目设置",
                    draft: draftBinding,
                    canEditName: true,
                    onDelete: nil,
                    onSave: {
                        let draft = draftBinding.wrappedValue
                        guard validateExistingDraft(draft, excludingID: draft.id) else { return }
                        draftSheetTarget = nil
                    }
                )
            }
        }
    }
}
