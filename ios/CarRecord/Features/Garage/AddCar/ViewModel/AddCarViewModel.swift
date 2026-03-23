import SwiftUI
import Combine
import SwiftData

@MainActor
final class AddCarViewModel: ObservableObject {
    let editingCar: Car?

    @Published var brand: String
    @Published var modelName: String
    @Published var mileageWan: Int
    @Published var mileageQian: Int
    @Published var mileageBai: Int
    @Published var onRoadDate: Date
    @Published var draftOnRoadDate: Date
    @Published var activePickerSheet: CarPickerSheet?
    @Published var itemDrafts: [MaintenanceItemDraft] = []
    @Published var existingItemDrafts: [MaintenanceItemDraft] = []
    @Published var customDraft = MaintenanceItemDraft.defaultDraft(name: "自定义项目")
    @Published var draftSheetTarget: MaintenanceDraftSheetTarget?
    @Published var saveErrorMessage = ""
    @Published var isSaveErrorAlertPresented = false
    @Published var validationMessage = ""
    @Published var isValidationAlertPresented = false

    private static let fixedBrandOptions = [
        "本田",
        "日产",
    ]

    static func modelOptions(for brand: String) -> [String] {
        switch brand {
        case "本田":
            return ["22款思域", "23款CR-V", "24款雅阁"]
        case "日产":
            return ["22款轩逸", "23款奇骏", "24款天籁"]
        default:
            return ["22款思域"]
        }
    }

    var brandOptions: [String] {
        Self.fixedBrandOptions
    }

    var displayModelOptions: [String] {
        Self.modelOptions(for: brand)
    }

    var navigationTitle: String {
        editingCar == nil ? "添加车辆" : "编辑车辆"
    }

    var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian, bai: mileageBai)
    }

    var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(editingCar: Car? = nil) {
        self.editingCar = editingCar

        if let editingCar {
            let segments = MileageSegmentFormatter.segments(from: editingCar.mileage)
            let normalizedBrand = Self.normalizedBrand(editingCar.brand)
            let normalizedModel = Self.normalizedModel(model: editingCar.modelName)
            brand = normalizedBrand
            modelName = normalizedModel
            mileageWan = segments.wan
            mileageQian = segments.qian
            mileageBai = segments.bai
            onRoadDate = editingCar.purchaseDate
            draftOnRoadDate = editingCar.purchaseDate
        } else {
            let now = AppDateContext.now()
            let defaultBrand = Self.fixedBrandOptions.first ?? "本田"
            brand = defaultBrand
            modelName = Self.modelOptions(for: defaultBrand).first ?? "22款思域"
            mileageWan = 0
            mileageQian = 0
            mileageBai = 0
            onRoadDate = now
            draftOnRoadDate = now
        }
    }

    func carModelKey(brand: String, modelName: String) -> String {
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(normalizedBrand)|\(normalizedModel)"
    }

    func presentPickerSheet(_ sheet: CarPickerSheet) {
        DispatchQueue.main.async {
            self.activePickerSheet = sheet
        }
    }

    func handleBrandChanged(maintenanceItemOptions: [MaintenanceItemOption]) {
        let options = Self.modelOptions(for: brand)
        if options.contains(modelName) == false {
            modelName = options.first ?? ""
        }
        rebuildItemDraftsForCurrentModel(maintenanceItemOptions: maintenanceItemOptions)
    }

    func handleModelChanged(maintenanceItemOptions: [MaintenanceItemOption]) {
        rebuildItemDraftsForCurrentModel(maintenanceItemOptions: maintenanceItemOptions)
    }

    func handleAppear(maintenanceItemOptions: [MaintenanceItemOption]) {
        rebuildItemDraftsForCurrentModel(maintenanceItemOptions: maintenanceItemOptions)
        rebuildExistingDraftsFromOptions(maintenanceItemOptions: maintenanceItemOptions)
    }

    func handleMaintenanceOptionsChanged(maintenanceItemOptions: [MaintenanceItemOption]) {
        rebuildExistingDraftsFromOptions(maintenanceItemOptions: maintenanceItemOptions)
    }

    func rebuildItemDraftsForCurrentModel(maintenanceItemOptions: [MaintenanceItemOption]) {
        guard maintenanceItemOptions.isEmpty else { return }
        let definitions = CoreConfig.defaultItemDefinitions(brand: brand, modelName: modelName)
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

    func rebuildExistingDraftsFromOptions(maintenanceItemOptions: [MaintenanceItemOption]) {
        guard maintenanceItemOptions.isEmpty == false else {
            existingItemDrafts = []
            return
        }
        let existingByID = Dictionary(uniqueKeysWithValues: existingItemDrafts.map { ($0.id, $0) })
        let options = CoreConfig.sortedSelectionOptions(options: maintenanceItemOptions, records: [])
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

    func draftEnabledBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { self.itemDrafts.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { isOn in
                guard let index = self.itemDrafts.firstIndex(where: { $0.id == id }) else { return }
                self.itemDrafts[index].isEnabled = isOn
            }
        )
    }

    func draftBinding(id: UUID) -> Binding<MaintenanceItemDraft>? {
        guard let index = itemDrafts.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.itemDrafts[index] },
            set: { self.itemDrafts[index] = $0 }
        )
    }

    func existingDraftBinding(optionID: UUID) -> Binding<MaintenanceItemDraft>? {
        guard let index = existingItemDrafts.firstIndex(where: { $0.id == optionID }) else { return nil }
        return Binding(
            get: { self.existingItemDrafts[index] },
            set: { self.existingItemDrafts[index] = $0 }
        )
    }

    func removeCustomDraft(_ id: UUID) {
        itemDrafts.removeAll { $0.id == id && $0.isDefault == false }
    }

    func saveCar(cars: [Car], maintenanceItemOptions: [MaintenanceItemOption], modelContext: ModelContext) -> Bool {
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetModelKey = carModelKey(brand: normalizedBrand, modelName: normalizedModelName)
        let currentEditingID = editingCar?.id

        if let conflictCar = cars.first(where: { car in
            if let currentEditingID, car.id == currentEditingID {
                return false
            }
            return carModelKey(brand: car.brand, modelName: car.modelName) == targetModelKey
        }) {
            saveErrorMessage = "车型“\(conflictCar.brand) \(conflictCar.modelName)”已存在，不能重复添加。"
            isSaveErrorAlertPresented = true
            return false
        }

        if maintenanceItemOptions.isEmpty {
            guard setupMaintenanceItemsForCurrentCar(modelContext: modelContext) else {
                return false
            }
        } else {
            guard applyExistingMaintenanceItemsChanges(maintenanceItemOptions: maintenanceItemOptions) else {
                return false
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
            return false
        }
        return true
    }

    func setupMaintenanceItemsForCurrentCar(modelContext: ModelContext) -> Bool {
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
            let thresholds = CoreConfig.normalizedProgressThresholds(
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

    func validateDraft(_ draft: MaintenanceItemDraft, excludingID: UUID?) -> Bool {
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

        let thresholds = CoreConfig.normalizedProgressThresholds(
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

    func validateExistingDraft(_ draft: MaintenanceItemDraft, excludingID: UUID?) -> Bool {
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

        let thresholds = CoreConfig.normalizedProgressThresholds(
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

    func applyExistingMaintenanceItemsChanges(maintenanceItemOptions: [MaintenanceItemOption]) -> Bool {
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
            let thresholds = CoreConfig.normalizedProgressThresholds(
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

    func monthIntervalYearBinding(for draft: Binding<MaintenanceItemDraft>) -> Binding<Double> {
        Binding(
            get: { max(0.5, Double(max(1, draft.wrappedValue.monthInterval)) / 12.0) },
            set: { newValue in
                draft.wrappedValue.monthInterval = max(1, Int((newValue * 12).rounded()))
            }
        )
    }

    func yearIntervalText(from monthInterval: Int) -> String {
        let years = Double(max(1, monthInterval)) / 12.0
        if years.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(years))"
        }
        return String(format: "%.1f", years)
    }

    private static func normalizedBrand(_ brand: String) -> String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedModel(model: String) -> String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
