import SwiftUI
import SwiftData

extension AddCarView {
    func rebuildItemDraftsForCurrentModel() {
        guard maintenanceItemOptions.isEmpty else { return }
        let definitions = MaintenanceItemCatalog.defaultItemDefinitions(brand: brand, modelName: modelName)
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
    func rebuildExistingDraftsFromOptions() {
        guard maintenanceItemOptions.isEmpty == false else {
            existingItemDrafts = []
            return
        }
        let existingByID = Dictionary(uniqueKeysWithValues: existingItemDrafts.map { ($0.id, $0) })
        let options = MaintenanceItemCatalog.sortedSelectionOptions(options: maintenanceItemOptions, records: [])
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
    func draftEnabledBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { itemDrafts.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { isOn in
                guard let index = itemDrafts.firstIndex(where: { $0.id == id }) else { return }
                itemDrafts[index].isEnabled = isOn
            }
        )
    }

    /// 通过 ID 获取项目草稿绑定，供设置弹窗编辑。
    func draftBinding(id: UUID) -> Binding<MaintenanceItemDraft>? {
        guard let index = itemDrafts.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { itemDrafts[index] },
            set: { itemDrafts[index] = $0 }
        )
    }

    /// 已有项目草稿绑定：按项目ID编辑并在“保存车辆”时统一回写。
    func existingDraftBinding(optionID: UUID) -> Binding<MaintenanceItemDraft>? {
        guard let index = existingItemDrafts.firstIndex(where: { $0.id == optionID }) else { return nil }
        return Binding(
            get: { existingItemDrafts[index] },
            set: { existingItemDrafts[index] = $0 }
        )
    }

    /// 删除自定义项目草稿。
    func removeCustomDraft(_ id: UUID) {
        itemDrafts.removeAll { $0.id == id && $0.isDefault == false }
    }

    /// 校验单个项目草稿：名称、提醒方式与阈值都必须合法。
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

        let thresholds = MaintenanceItemCatalog.normalizedProgressThresholds(
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

        let thresholds = MaintenanceItemCatalog.normalizedProgressThresholds(
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
    func applyExistingMaintenanceItemsChanges() -> Bool {
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
            let thresholds = MaintenanceItemCatalog.normalizedProgressThresholds(
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
    /// 把 monthInterval 映射为“年”步进器，避免用户在月单位下频繁换算。
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

}
