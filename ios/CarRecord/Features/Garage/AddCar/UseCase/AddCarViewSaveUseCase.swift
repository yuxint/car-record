import SwiftUI
import SwiftData

extension AddCarView {
    func saveCar() {
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
    func setupMaintenanceItemsForCurrentCar() -> Bool {
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

}
