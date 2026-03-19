import SwiftUI
import SwiftData

/// 新增/编辑车辆页：全部使用选择器，避免唤醒系统输入法。
struct AddCarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) private var cars: [Car]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]

    let editingCar: Car?

    @State private var brand: String
    @State private var modelName: String
    @State private var mileageWan: Int
    @State private var mileageQian: Int
    @State private var mileageBai: Int
    @State private var onRoadDate: Date
    @State private var draftOnRoadDate: Date
    @State private var activePickerSheet: CarPickerSheet?
    @State private var itemDrafts: [MaintenanceItemDraft] = []
    @State private var existingItemDrafts: [MaintenanceItemDraft] = []
    @State private var customDraft = MaintenanceItemDraft.newCustom()
    @State private var draftSheetTarget: MaintenanceDraftSheetTarget?
    @State private var saveErrorMessage = ""
    @State private var isSaveErrorAlertPresented = false
    @State private var validationMessage = ""
    @State private var isValidationAlertPresented = false

    /// 固定品牌选项：先限制为小范围，后续按业务扩展。
    private static let fixedBrandOptions = [
        "本田",
        "日产",
    ]

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
            Form {
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

                Section("保养项目设置") {
                    if maintenanceItemOptions.isEmpty {
                        ForEach(itemDrafts) { draft in
                            HStack(spacing: 12) {
                                Button {
                                    draftSheetTarget = .edit(draft.id)
                                } label: {
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

                        Button {
                            customDraft = MaintenanceItemDraft.newCustom()
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
                            HStack(spacing: 8) {
                                Button {
                                    draftSheetTarget = .editExisting(draft.id)
                                } label: {
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
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }

                        Text("点任一项目可直接修改名称、提醒规则和阈值；与新增车辆页保持一致。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
    }

    @ViewBuilder
    private var mileagePickerSheet: some View {
        MileagePickerSheetView(
            title: "选择里程",
            wan: $mileageWan,
            qian: $mileageQian,
            bai: $mileageBai,
            onCancel: { activePickerSheet = nil },
            onConfirm: { activePickerSheet = nil }
        )
    }

    @ViewBuilder
    private var onRoadDatePickerSheet: some View {
        DayDatePickerSheetView(
            title: "选择日期",
            label: "上路日期",
            draftDate: $draftOnRoadDate,
            currentDate: onRoadDate,
            onApply: { newValue in
                onRoadDate = newValue
                activePickerSheet = nil
            },
            onCancel: { activePickerSheet = nil }
        )
    }

    /// 合并“万 + 千 + 百”三段，得到实际公里数。
    private var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian, bai: mileageBai)
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
        let targetModelKey = carModelKey(brand: normalizedBrand, modelName: normalizedModelName)
        let currentEditingID = editingCar?.id

        /// 同车型唯一约束：同一品牌+车型只允许存在一辆车。
        if let conflictCar = cars.first(where: { car in
            if let currentEditingID, car.id == currentEditingID {
                return false
            }
            return carModelKey(brand: car.brand, modelName: car.modelName) == targetModelKey
        }) {
            saveErrorMessage = "车型“\(conflictCar.brand) \(conflictCar.modelName)”已存在，不能重复添加。"
            isSaveErrorAlertPresented = true
            return
        }

        /// 无项目配置时允许在同页初始化，避免还要二次跳转到项目管理页。
        if maintenanceItemOptions.isEmpty {
            guard setupMaintenanceItemsForCurrentCar() else {
                return
            }
        } else {
            guard applyExistingMaintenanceItemsChanges() else {
                return
            }
        }

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

        if let message = modelContext.saveOrLog("保存车辆") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
            return
        }
        dismiss()
    }

    /// 生成初始保养项目并保存；失败时会弹出统一错误提示。
    private func setupMaintenanceItemsForCurrentCar() -> Bool {
        let enabledDrafts = itemDrafts.filter(\.isEnabled)
        guard enabledDrafts.isEmpty == false else {
            validationMessage = "请至少保留一个默认项目或新增一个自定义项目。"
            isValidationAlertPresented = true
            return false
        }
        var seenNames = Set<String>()
        for draft in enabledDrafts {
            let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if seenNames.contains(normalizedName) {
                validationMessage = "存在重名项目，请先调整后再保存。"
                isValidationAlertPresented = true
                return false
            }
            seenNames.insert(normalizedName)
        }

        for draft in enabledDrafts {
            let thresholds = MaintenanceItemConfig.normalizedProgressThresholds(
                warning: draft.warningStartPercent,
                danger: draft.dangerStartPercent
            )
            modelContext.insert(
                MaintenanceItemOption(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    isDefault: draft.isDefault,
                    catalogKey: draft.catalogKey,
                    remindByMileage: draft.remindByMileage,
                    mileageInterval: draft.remindByMileage ? max(1, draft.mileageInterval) : 0,
                    remindByTime: draft.remindByTime,
                    monthInterval: draft.remindByTime ? max(1, draft.monthInterval) : 0,
                    warningStartPercent: thresholds.warning,
                    dangerStartPercent: thresholds.danger
                )
            )
        }

        if let message = modelContext.saveOrLog("初始化保养项目") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
            return false
        }
        return true
    }

    /// 品牌/车型切换时重建默认项目草稿，并保留已录入的自定义项目和已调参数。
    private func rebuildItemDraftsForCurrentModel() {
        guard maintenanceItemOptions.isEmpty else { return }
        let definitions = MaintenanceItemConfig.defaultItemDefinitions(brand: brand, modelName: modelName)
        let existingDefaultByKey = Dictionary(
            uniqueKeysWithValues: itemDrafts.compactMap { draft -> (String, MaintenanceItemDraft)? in
                guard draft.isDefault, let key = draft.catalogKey else { return nil }
                return (key, draft)
            }
        )
        let customDrafts = itemDrafts.filter { $0.isDefault == false }

        let defaultDrafts = definitions.map { definition in
            if var existing = existingDefaultByKey[definition.key] {
                existing.name = definition.defaultName
                existing.catalogKey = definition.key
                return existing
            }
            return MaintenanceItemDraft.defaultDraft(from: definition)
        }

        itemDrafts = defaultDrafts + customDrafts
    }

    /// 已有保养项目时，按“项目ID”生成可编辑草稿，保存车辆时再统一写回。
    private func rebuildExistingDraftsFromOptions() {
        guard maintenanceItemOptions.isEmpty == false else {
            existingItemDrafts = []
            return
        }
        let existingByID = Dictionary(uniqueKeysWithValues: existingItemDrafts.map { ($0.id, $0) })
        let options = MaintenanceItemConfig.naturalSortedOptions(maintenanceItemOptions)
        existingItemDrafts = options.map { option in
            if var existing = existingByID[option.id] {
                existing.isDefault = option.isDefault
                existing.catalogKey = option.catalogKey
                return existing
            }
            return MaintenanceItemDraft(
                id: option.id,
                name: option.name,
                isDefault: option.isDefault,
                catalogKey: option.catalogKey,
                isEnabled: true,
                remindByMileage: option.remindByMileage,
                mileageInterval: max(1, option.mileageInterval == 0 ? 5000 : option.mileageInterval),
                remindByTime: option.remindByTime,
                monthInterval: max(1, option.monthInterval == 0 ? 12 : option.monthInterval),
                warningStartPercent: option.warningStartPercent,
                dangerStartPercent: option.dangerStartPercent
            )
        }
    }

    /// 草稿启用状态绑定：用于列表开关直接回写。
    private func draftEnabledBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { itemDrafts.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { isOn in
                guard let index = itemDrafts.firstIndex(where: { $0.id == id }) else { return }
                itemDrafts[index].isEnabled = isOn
            }
        )
    }

    /// 通过 ID 获取项目草稿绑定，供设置弹窗编辑。
    private func draftBinding(id: UUID) -> Binding<MaintenanceItemDraft>? {
        guard let index = itemDrafts.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { itemDrafts[index] },
            set: { itemDrafts[index] = $0 }
        )
    }

    /// 已有项目草稿绑定：按项目ID编辑并在“保存车辆”时统一回写。
    private func existingDraftBinding(optionID: UUID) -> Binding<MaintenanceItemDraft>? {
        guard let index = existingItemDrafts.firstIndex(where: { $0.id == optionID }) else { return nil }
        return Binding(
            get: { existingItemDrafts[index] },
            set: { existingItemDrafts[index] = $0 }
        )
    }

    /// 删除自定义项目草稿。
    private func removeCustomDraft(_ id: UUID) {
        itemDrafts.removeAll { $0.id == id && $0.isDefault == false }
    }

    /// 校验单个项目草稿：名称、提醒方式与阈值都必须合法。
    private func validateDraft(_ draft: MaintenanceItemDraft, excludingID: UUID?) -> Bool {
        let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else {
            validationMessage = "项目名称不能为空。"
            isValidationAlertPresented = true
            return false
        }

        let duplicateInDrafts = itemDrafts.contains { existing in
            if let excludingID, existing.id == excludingID {
                return false
            }
            return existing.name.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
        }
        if duplicateInDrafts {
            validationMessage = "项目名称已存在，请更换后再保存。"
            isValidationAlertPresented = true
            return false
        }

        guard draft.remindByMileage || draft.remindByTime else {
            validationMessage = "请至少开启一种提醒方式。"
            isValidationAlertPresented = true
            return false
        }

        let thresholds = MaintenanceItemConfig.normalizedProgressThresholds(
            warning: draft.warningStartPercent,
            danger: draft.dangerStartPercent
        )
        guard thresholds.danger > thresholds.warning else {
            validationMessage = "红色阈值必须大于黄色阈值。"
            isValidationAlertPresented = true
            return false
        }
        return true
    }

    /// 校验已有项目草稿：与首次新增草稿保持同一套规则，避免行为不一致。
    private func validateExistingDraft(_ draft: MaintenanceItemDraft, excludingID: UUID?) -> Bool {
        let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else {
            validationMessage = "项目名称不能为空。"
            isValidationAlertPresented = true
            return false
        }

        let duplicateInDrafts = existingItemDrafts.contains { existing in
            if let excludingID, existing.id == excludingID {
                return false
            }
            return existing.name.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
        }
        if duplicateInDrafts {
            validationMessage = "项目名称已存在，请更换后再保存。"
            isValidationAlertPresented = true
            return false
        }

        guard draft.remindByMileage || draft.remindByTime else {
            validationMessage = "请至少开启一种提醒方式。"
            isValidationAlertPresented = true
            return false
        }

        let thresholds = MaintenanceItemConfig.normalizedProgressThresholds(
            warning: draft.warningStartPercent,
            danger: draft.dangerStartPercent
        )
        guard thresholds.danger > thresholds.warning else {
            validationMessage = "红色阈值必须大于黄色阈值。"
            isValidationAlertPresented = true
            return false
        }
        return true
    }

    /// 把编辑页中修改过的已有项目草稿统一写回模型对象。
    private func applyExistingMaintenanceItemsChanges() -> Bool {
        guard existingItemDrafts.isEmpty == false else { return true }
        var seenNames = Set<String>()
        for draft in existingItemDrafts {
            guard validateExistingDraft(draft, excludingID: draft.id) else {
                return false
            }
            let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if seenNames.contains(normalizedName) {
                validationMessage = "存在重名项目，请先调整后再保存。"
                isValidationAlertPresented = true
                return false
            }
            seenNames.insert(normalizedName)
        }

        let optionByID = Dictionary(uniqueKeysWithValues: maintenanceItemOptions.map { ($0.id, $0) })
        for draft in existingItemDrafts {
            guard let option = optionByID[draft.id] else { continue }
            let thresholds = MaintenanceItemConfig.normalizedProgressThresholds(
                warning: draft.warningStartPercent,
                danger: draft.dangerStartPercent
            )
            option.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            option.remindByMileage = draft.remindByMileage
            option.mileageInterval = draft.remindByMileage ? max(1, draft.mileageInterval) : 0
            option.remindByTime = draft.remindByTime
            option.monthInterval = draft.remindByTime ? max(1, draft.monthInterval) : 0
            option.warningStartPercent = thresholds.warning
            option.dangerStartPercent = thresholds.danger
        }
        return true
    }

    /// 项目设置弹窗：统一编辑名称、提醒方式和阈值。
    @ViewBuilder
    private func maintenanceDraftEditorSheet(
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
                            value: monthIntervalYearBinding(for: draft),
                            in: 0.5...10,
                            step: 0.5
                        ) {
                            Text("时间间隔：\(yearIntervalText(from: draft.wrappedValue.monthInterval))年")
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
                        draftSheetTarget = nil
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

    /// 把 monthInterval 映射为“年”步进器，避免用户在月单位下频繁换算。
    private func monthIntervalYearBinding(for draft: Binding<MaintenanceItemDraft>) -> Binding<Double> {
        Binding(
            get: { max(0.5, Double(max(1, draft.wrappedValue.monthInterval)) / 12.0) },
            set: { newValue in
                draft.wrappedValue.monthInterval = max(1, Int((newValue * 12).rounded()))
            }
        )
    }

    private func yearIntervalText(from monthInterval: Int) -> String {
        let years = Double(max(1, monthInterval)) / 12.0
        if years.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(years))"
        }
        return String(format: "%.1f", years)
    }

    /// 车型唯一键：按“品牌+车型”归一化后匹配，避免空格差异导致重复。
    private func carModelKey(brand: String, modelName: String) -> String {
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(normalizedBrand)|\(normalizedModel)"
    }

    /// 统一拉起弹窗：规避首次进入页面时按钮点击偶发失效的问题。
    private func presentPickerSheet(_ sheet: CarPickerSheet) {
        DispatchQueue.main.async {
            activePickerSheet = sheet
        }
    }

    /// 品牌对应车型：先按明确规则固定，后续再按车型库扩展。
    private static func modelOptions(for brand: String) -> [String] {
        switch brand {
        case "日产":
            return ["轩逸"]
        default:
            return ["22款思域"]
        }
    }

    private static func normalizedBrand(_ raw: String) -> String {
        if raw == "东风本田" || raw == "本田" {
            return "本田"
        }
        if raw == "日产" {
            return "日产"
        }
        return "本田"
    }

    private static func normalizedModel(brand: String, model: String) -> String {
        let options = modelOptions(for: brand)
        if options.contains(model) {
            return model
        }
        return options.first ?? model
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

/// 保养项目设置弹窗路由：区分“编辑项目”与“新增自定义项目”。
private enum MaintenanceDraftSheetTarget: Identifiable {
    case edit(UUID)
    case addCustom
    case editExisting(UUID)

    var id: String {
        switch self {
        case .edit(let id):
            return "edit-\(id.uuidString)"
        case .addCustom:
            return "add-custom"
        case .editExisting(let id):
            return "edit-existing-\(id.uuidString)"
        }
    }
}

/// 添加车辆页的保养项目草稿模型：承载首次设置时的全部可编辑配置。
private struct MaintenanceItemDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var isDefault: Bool
    var catalogKey: String?
    var isEnabled: Bool
    var remindByMileage: Bool
    var mileageInterval: Int
    var remindByTime: Bool
    var monthInterval: Int
    var warningStartPercent: Int
    var dangerStartPercent: Int

    static func defaultDraft(from definition: MaintenanceItemConfig.DefaultItemDefinition) -> MaintenanceItemDraft {
        MaintenanceItemDraft(
            name: definition.defaultName,
            isDefault: true,
            catalogKey: definition.key,
            isEnabled: true,
            remindByMileage: definition.mileageInterval != nil,
            mileageInterval: definition.mileageInterval ?? 5000,
            remindByTime: definition.monthInterval != nil,
            monthInterval: definition.monthInterval ?? 12,
            warningStartPercent: MaintenanceItemConfig.defaultWarningStartPercent,
            dangerStartPercent: MaintenanceItemConfig.defaultDangerStartPercent
        )
    }

    static func newCustom() -> MaintenanceItemDraft {
        MaintenanceItemDraft(
            name: "",
            isDefault: false,
            catalogKey: nil,
            isEnabled: true,
            remindByMileage: true,
            mileageInterval: 5000,
            remindByTime: false,
            monthInterval: 12,
            warningStartPercent: MaintenanceItemConfig.defaultWarningStartPercent,
            dangerStartPercent: MaintenanceItemConfig.defaultDangerStartPercent
        )
    }

    static func reminderSummary(for draft: MaintenanceItemDraft) -> String {
        var parts: [String] = []
        if draft.remindByMileage {
            parts.append("\(max(1, draft.mileageInterval)) km")
        }
        if draft.remindByTime {
            let years = Double(max(1, draft.monthInterval)) / 12.0
            let yearText: String
            if years.truncatingRemainder(dividingBy: 1) == 0 {
                yearText = "\(Int(years))年"
            } else {
                yearText = "\(String(format: "%.1f", years))年"
            }
            parts.append(yearText)
        }
        if parts.isEmpty {
            parts.append("未设置")
        }
        return "\(parts.joined(separator: " / ")) · 阈值\(draft.warningStartPercent)%/\(draft.dangerStartPercent)%"
    }
}
