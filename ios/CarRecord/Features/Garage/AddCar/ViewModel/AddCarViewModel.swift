import SwiftUI
import Combine
import SwiftData

@MainActor
final class AddCarViewModel: ObservableObject {
    let editingCar: Car?
    private let initialEditingModelKey: String?

    @Published var brand: String
    @Published var modelName: String
    @Published var mileageWan: Int
    @Published var mileageQian: Int
    @Published var mileageBai: Int
    @Published var onRoadDate: Date
    @Published var activePickerSheet: CarPickerSheet?
    @Published var itemDrafts: [MaintenanceItemDraft] = []
    @Published var existingItemDrafts: [MaintenanceItemDraft] = []
    @Published private(set) var visibleDefaultCatalogKeys = Set<String>()
    @Published var customDraft = MaintenanceItemDraft.defaultDraft(
        name: "",
        warningStartPercent: CoreConfig.fallbackModelConfig.defaultWarningStartPercent,
        dangerStartPercent: CoreConfig.fallbackModelConfig.defaultDangerStartPercent
    )
    @Published var draftSheetTarget: MaintenanceDraftSheetTarget?
    @Published var saveErrorMessage = ""
    @Published var isSaveErrorAlertPresented = false
    @Published var validationMessage = ""
    @Published var isValidationAlertPresented = false
    private var hasInitializedDraftsOnAppear = false

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

    var displayExistingItemDrafts: [MaintenanceItemDraft] {
        existingItemDrafts.filter { draft in
            guard draft.isDefault else { return true }
            guard let catalogKey = draft.catalogKey else { return true }
            return visibleDefaultCatalogKeys.contains(catalogKey)
        }
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

    var currentModelConfig: CoreConfig.ModelConfig {
        CoreConfig.modelConfig(brand: brand, modelName: modelName)
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
            initialEditingModelKey = Self.makeModelKey(brand: normalizedBrand, model: normalizedModel)
        } else {
            let now = AppDateContext.now()
            let defaultBrand = Self.fixedBrandOptions.first ?? "本田"
            brand = defaultBrand
            modelName = Self.modelOptions(for: defaultBrand).first ?? "22款思域"
            mileageWan = 0
            mileageQian = 0
            mileageBai = 0
            onRoadDate = now
            initialEditingModelKey = nil
        }
        customDraft = makeDefaultCustomDraft()
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
        rebuildExistingDraftsFromOptions(maintenanceItemOptions: maintenanceItemOptions)
    }

    func handleModelChanged(maintenanceItemOptions: [MaintenanceItemOption]) {
        rebuildItemDraftsForCurrentModel(maintenanceItemOptions: maintenanceItemOptions)
        rebuildExistingDraftsFromOptions(maintenanceItemOptions: maintenanceItemOptions)
    }

    func handleAppear(maintenanceItemOptions: [MaintenanceItemOption]) {
        guard hasInitializedDraftsOnAppear == false else { return }
        hasInitializedDraftsOnAppear = true
        rebuildItemDraftsForCurrentModel(maintenanceItemOptions: maintenanceItemOptions)
        rebuildExistingDraftsFromOptions(maintenanceItemOptions: maintenanceItemOptions)
    }

    func handleMaintenanceOptionsChanged(maintenanceItemOptions: [MaintenanceItemOption]) {
        rebuildExistingDraftsFromOptions(maintenanceItemOptions: maintenanceItemOptions)
    }

    func rebuildItemDraftsForCurrentModel(maintenanceItemOptions: [MaintenanceItemOption]) {
        guard maintenanceItemOptions.isEmpty else { return }
        let definitions = CoreConfig.defaultItemDefinitions(brand: brand, modelName: modelName)
        visibleDefaultCatalogKeys = Set(definitions.map(\.key))
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
            return MaintenanceItemDraft.defaultDraft(
                from: definition,
                warningStartPercent: currentModelConfig.defaultWarningStartPercent,
                dangerStartPercent: currentModelConfig.defaultDangerStartPercent
            )
        }

        itemDrafts = defaultDrafts + customDrafts
    }

    func rebuildExistingDraftsFromOptions(maintenanceItemOptions: [MaintenanceItemOption]) {
        guard maintenanceItemOptions.isEmpty == false else {
            existingItemDrafts = []
            visibleDefaultCatalogKeys = []
            return
        }
        let definitions = CoreConfig.defaultItemDefinitions(brand: brand, modelName: modelName)
        let definitionsByKey = Dictionary(uniqueKeysWithValues: definitions.map { ($0.key, $0) })
        let allowedDefaultKeys = Set(definitionsByKey.keys)
        visibleDefaultCatalogKeys = allowedDefaultKeys
        let currentModelKey = Self.makeModelKey(brand: brand, model: modelName)
        let shouldApplyPersistedDisabledState = currentModelKey == initialEditingModelKey
        let disabledItemIDs: Set<UUID>
        if shouldApplyPersistedDisabledState {
            disabledItemIDs = editingCar.map { Set(CoreConfig.parseItemIDs($0.disabledItemIDsRaw)) } ?? []
        } else {
            disabledItemIDs = []
        }
        let existingByID = Dictionary(uniqueKeysWithValues: existingItemDrafts.map { ($0.id, $0) })
        let options = CoreConfig.sortedSelectionOptions(
            options: maintenanceItemOptions,
            records: [],
            brand: brand,
            modelName: modelName
        )
        let drafts = options.map { option in
            let normalizedName = option.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let isModelAllowedDefault = option.isDefault == false || allowedDefaultKeys.contains(option.catalogKey ?? "")
            let isEnabledByModel = isModelAllowedDefault
            if var existing = existingByID[option.id] {
                existing.isDefault = option.isDefault
                existing.catalogKey = option.catalogKey
                if let definition = definitionForOption(option, definitionsByKey: definitionsByKey) {
                    existing.name = definition.defaultName
                    existing.remindByMileage = definition.mileageInterval != nil
                    existing.mileageInterval = definition.mileageInterval ?? 0
                    existing.remindByTime = definition.monthInterval != nil
                    existing.monthInterval = definition.monthInterval ?? 0
                } else {
                    existing.name = normalizedName
                }
                existing.isEnabled = isEnabledByModel && disabledItemIDs.contains(option.id) == false
                return existing
            }
            return MaintenanceItemDraft(
                id: option.id,
                name: definitionForOption(option, definitionsByKey: definitionsByKey)?.defaultName ?? normalizedName,
                isDefault: option.isDefault,
                catalogKey: option.catalogKey,
                isEnabled: isEnabledByModel && disabledItemIDs.contains(option.id) == false,
                remindByMileage: definitionForOption(option, definitionsByKey: definitionsByKey)?.mileageInterval != nil
                    ? true
                    : option.remindByMileage,
                mileageInterval: definitionForOption(option, definitionsByKey: definitionsByKey)?.mileageInterval
                    ?? max(1, option.mileageInterval == 0 ? 5000 : option.mileageInterval),
                remindByTime: definitionForOption(option, definitionsByKey: definitionsByKey)?.monthInterval != nil
                    ? true
                    : option.remindByTime,
                monthInterval: definitionForOption(option, definitionsByKey: definitionsByKey)?.monthInterval
                    ?? max(1, option.monthInterval == 0 ? 12 : option.monthInterval),
                warningStartPercent: option.warningStartPercent,
                dangerStartPercent: option.dangerStartPercent
            )
        }
        let enabledDrafts = drafts.filter(\.isEnabled)
        let disabledDrafts = drafts.filter { $0.isEnabled == false }
        existingItemDrafts = enabledDrafts + disabledDrafts
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

    func existingDraftEnabledBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { self.existingItemDrafts.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { isOn in
                guard let index = self.existingItemDrafts.firstIndex(where: { $0.id == id }) else { return }
                self.existingItemDrafts[index].isEnabled = isOn
            }
        )
    }

    func removeCustomDraft(_ id: UUID) {
        itemDrafts.removeAll { $0.id == id && $0.isDefault == false }
    }

    func removeExistingCustomDraft(_ id: UUID) {
        existingItemDrafts.removeAll { $0.id == id && $0.isDefault == false }
    }

    func saveCar(cars: [Car], maintenanceItemOptions: [MaintenanceItemOption], modelContext: ModelContext) -> Bool {
        let normalizedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetCarID = editingCar?.id ?? UUID()
        if editingCar == nil {
            let targetModelKey = carModelKey(brand: normalizedBrand, modelName: normalizedModelName)
            if let conflictCar = cars.first(where: { car in
                carModelKey(brand: car.brand, modelName: car.modelName) == targetModelKey
            }) {
                saveErrorMessage = "车型“\(conflictCar.brand) \(conflictCar.modelName)”已存在，不能重复添加。"
                isSaveErrorAlertPresented = true
                return false
            }
        }

        if maintenanceItemOptions.isEmpty {
            guard setupMaintenanceItemsForCurrentCar(carID: targetCarID, modelContext: modelContext) else {
                return false
            }
        } else {
            guard applyExistingMaintenanceItemsChanges(
                carID: targetCarID,
                maintenanceItemOptions: maintenanceItemOptions,
                modelContext: modelContext
            ) else {
                return false
            }
        }

        let disabledItemIDsRaw: String
        if maintenanceItemOptions.isEmpty {
            let disabledIDs = itemDrafts
                .filter { $0.isEnabled == false }
                .map(\.id)
            disabledItemIDsRaw = CoreConfig.joinItemIDs(disabledIDs)
        } else {
            let disabledIDs = displayExistingItemDrafts
                .filter { $0.isEnabled == false }
                .map(\.id)
            disabledItemIDsRaw = CoreConfig.joinItemIDs(disabledIDs)
        }

        if let editingCar {
            editingCar.mileage = currentMileage
            editingCar.purchaseDate = onRoadDate
            editingCar.disabledItemIDsRaw = disabledItemIDsRaw
        } else {
            let car = Car(
                id: targetCarID,
                brand: normalizedBrand,
                modelName: normalizedModelName,
                mileage: currentMileage,
                purchaseDate: onRoadDate,
                disabledItemIDsRaw: disabledItemIDsRaw
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

    func setupMaintenanceItemsForCurrentCar(carID: UUID, modelContext: ModelContext) -> Bool {
        let enabledDrafts = itemDrafts.filter(\.isEnabled)
        guard enabledDrafts.isEmpty == false else {
            validationMessage = "请至少保留一个默认项目或新增一个自定义项目。"
            isValidationAlertPresented = true
            return false
        }
        var seenNames = Set<String>()
        for draft in itemDrafts {
            let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if seenNames.contains(normalizedName) {
                validationMessage = "存在重名项目，请先调整后再保存。"
                isValidationAlertPresented = true
                return false
            }
            seenNames.insert(normalizedName)
        }

        for draft in itemDrafts {
            let thresholds = CoreConfig.normalizedProgressThresholds(
                warning: draft.warningStartPercent,
                danger: draft.dangerStartPercent
            )
            modelContext.insert(
                MaintenanceItemOption(
                    id: draft.id,
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    ownerCarID: carID,
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

    func validateDraftError(_ draft: MaintenanceItemDraft, excludingID: UUID?) -> String? {
        let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else {
            return "项目名称不能为空。"
        }

        let duplicateInDrafts = itemDrafts.contains { existing in
            if let excludingID, existing.id == excludingID {
                return false
            }
            return existing.name.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
        }
        if duplicateInDrafts {
            return "项目名称已存在，请更换后再保存。"
        }

        guard draft.remindByMileage || draft.remindByTime else {
            return "请至少开启一种提醒方式。"
        }

        guard (0...200).contains(draft.warningStartPercent), (0...200).contains(draft.dangerStartPercent) else {
            return "阈值范围必须在 0%~200%。"
        }

        guard draft.dangerStartPercent > draft.warningStartPercent else {
            return "红色阈值必须大于黄色阈值。"
        }
        return nil
    }

    func validateDraft(_ draft: MaintenanceItemDraft, excludingID: UUID?) -> Bool {
        if let message = validateDraftError(draft, excludingID: excludingID) {
            validationMessage = message
            isValidationAlertPresented = true
            return false
        }
        return true
    }

    func validateExistingDraftError(_ draft: MaintenanceItemDraft, excludingID: UUID?) -> String? {
        let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else {
            return "项目名称不能为空。"
        }

        let duplicateInDrafts = existingItemDrafts.contains { existing in
            if let excludingID, existing.id == excludingID {
                return false
            }
            return existing.name.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedName
        }
        if duplicateInDrafts {
            return "项目名称已存在，请更换后再保存。"
        }

        guard draft.remindByMileage || draft.remindByTime else {
            return "请至少开启一种提醒方式。"
        }

        guard (0...200).contains(draft.warningStartPercent), (0...200).contains(draft.dangerStartPercent) else {
            return "阈值范围必须在 0%~200%。"
        }

        guard draft.dangerStartPercent > draft.warningStartPercent else {
            return "红色阈值必须大于黄色阈值。"
        }
        return nil
    }

    func validateExistingDraft(_ draft: MaintenanceItemDraft, excludingID: UUID?) -> Bool {
        if let message = validateExistingDraftError(draft, excludingID: excludingID) {
            validationMessage = message
            isValidationAlertPresented = true
            return false
        }
        return true
    }

    func applyExistingMaintenanceItemsChanges(
        carID: UUID,
        maintenanceItemOptions: [MaintenanceItemOption],
        modelContext: ModelContext
    ) -> Bool {
        guard existingItemDrafts.isEmpty == false else { return true }
        let currentDraftIDs = Set(existingItemDrafts.map(\.id))
        for option in maintenanceItemOptions where option.isDefault == false {
            if currentDraftIDs.contains(option.id) == false {
                modelContext.delete(option)
            }
        }
        let enabledDrafts = existingItemDrafts.filter(\.isEnabled)
        guard enabledDrafts.isEmpty == false else {
            validationMessage = "请至少保留一个保养项目。"
            isValidationAlertPresented = true
            return false
        }
        var seenNames = Set<String>()
        for draft in enabledDrafts {
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
        for draft in enabledDrafts {
            let thresholds = CoreConfig.normalizedProgressThresholds(
                warning: draft.warningStartPercent,
                danger: draft.dangerStartPercent
            )
            if let option = optionByID[draft.id] {
                option.ownerCarID = carID
                option.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                option.remindByMileage = draft.remindByMileage
                option.mileageInterval = draft.remindByMileage ? max(1, draft.mileageInterval) : 0
                option.remindByTime = draft.remindByTime
                option.monthInterval = draft.remindByTime ? max(1, draft.monthInterval) : 0
                option.warningStartPercent = thresholds.warning
                option.dangerStartPercent = thresholds.danger
            } else {
                modelContext.insert(
                    MaintenanceItemOption(
                        id: draft.id,
                        name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        ownerCarID: carID,
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

    func restoreDraftDefaults(_ draft: MaintenanceItemDraft) -> MaintenanceItemDraft {
        var restored = draft
        if restored.isDefault,
           let catalogKey = restored.catalogKey {
            let definitions = CoreConfig.defaultItemDefinitions(brand: brand, modelName: modelName)
            if let definition = definitions.first(where: { $0.key == catalogKey }) {
                restored.name = definition.defaultName
                restored.remindByMileage = definition.mileageInterval != nil
                restored.mileageInterval = definition.mileageInterval ?? 0
                restored.remindByTime = definition.monthInterval != nil
                restored.monthInterval = definition.monthInterval ?? 0
            }
        } else {
            let fallback = MaintenanceItemDraft.defaultDraft(
                name: restored.name,
                warningStartPercent: currentModelConfig.defaultWarningStartPercent,
                dangerStartPercent: currentModelConfig.defaultDangerStartPercent
            )
            restored.remindByMileage = fallback.remindByMileage
            restored.mileageInterval = fallback.mileageInterval
            restored.remindByTime = fallback.remindByTime
            restored.monthInterval = fallback.monthInterval
        }
        restored.warningStartPercent = currentModelConfig.defaultWarningStartPercent
        restored.dangerStartPercent = currentModelConfig.defaultDangerStartPercent
        return restored
    }

    func makeDefaultCustomDraft() -> MaintenanceItemDraft {
        MaintenanceItemDraft.defaultDraft(
            name: "",
            warningStartPercent: currentModelConfig.defaultWarningStartPercent,
            dangerStartPercent: currentModelConfig.defaultDangerStartPercent
        )
    }

    private static func normalizedBrand(_ brand: String) -> String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedModel(model: String) -> String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeModelKey(brand: String, model: String) -> String {
        "\(normalizedBrand(brand))|\(normalizedModel(model: model))"
    }

    private func definitionForOption(
        _ option: MaintenanceItemOption,
        definitionsByKey: [String: CoreConfig.DefaultItemDefinition]
    ) -> CoreConfig.DefaultItemDefinition? {
        guard option.isDefault, let catalogKey = option.catalogKey else { return nil }
        return definitionsByKey[catalogKey]
    }
}
