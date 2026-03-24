import Foundation
import SwiftData

extension MyView {
    /// 应用恢复数据并返回统计结果：会在空库中重建保养项目、车辆与记录。
    func applyImportedPayload(_ payload: MyDataTransferPayload) throws -> MyDataTransferImportSummary {
        AppLogger.info(
            "开始写入恢复数据",
            payload: "vehicles=\(payload.vehicles.count), modelProfiles=\(payload.modelProfiles.count)"
        )
        var summary = MyDataTransferImportSummary()
        var profileByKey: [String: MyDataTransferModelProfilePayload] = [:]
        for profile in payload.modelProfiles {
            let key = modelProfileKey(brand: profile.brand, modelName: profile.modelName)
            if profileByKey[key] != nil {
                throw NSError(
                    domain: "MyDataTransfer",
                    code: 1010,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(profile.brand) \(profile.modelName)”重复。"]
                )
            }
            profileByKey[key] = profile
        }

        if profileByKey.isEmpty, payload.vehicles.isEmpty == false {
            throw NSError(
                domain: "MyDataTransfer",
                code: 1011,
                userInfo: [NSLocalizedDescriptionKey: "恢复失败：备份缺少车型保养项目配置。"]
            )
        }

        var importedCarIDs = Set<UUID>()
        var importedModelKeys = Set<String>()
        var importedLogIDs = Set<UUID>()
        let dateOnlyFormatter = AppDateContext.makeDisplayFormatter("yyyy-MM-dd")
        dateOnlyFormatter.isLenient = false

        for vehicle in payload.vehicles {
            let carPayload = vehicle.car
            guard
                let parsedCarPurchaseDate = dateOnlyFormatter.date(from: carPayload.purchaseDate),
                dateOnlyFormatter.string(from: parsedCarPurchaseDate) == carPayload.purchaseDate
            else {
                throw NSError(
                    domain: "MyDataTransfer",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "车辆上路日期格式错误：\(carPayload.purchaseDate)。请使用 yyyy-MM-dd。"]
                )
            }
            if importedCarIDs.contains(carPayload.id) {
                throw NSError(
                    domain: "MyDataTransfer",
                    code: 1004,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：备份内车辆ID \(carPayload.id.uuidString) 重复。"]
                )
            }
            importedCarIDs.insert(carPayload.id)
            let profileKey = modelProfileKey(brand: carPayload.brand, modelName: carPayload.modelName)
            guard profileByKey[profileKey] != nil else {
                throw NSError(
                    domain: "MyDataTransfer",
                    code: 1013,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(carPayload.brand) \(carPayload.modelName)”缺少保养项目配置。"]
                )
            }

            /// 同车型唯一约束：恢复数据时也禁止同一品牌+车型出现多辆车。
            if importedModelKeys.contains(profileKey) {
                throw NSError(
                    domain: "MyDataTransfer",
                    code: 1014,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(carPayload.brand) \(carPayload.modelName)”重复，单一车型仅允许一辆车。"]
                )
            }
            importedModelKeys.insert(profileKey)
            let car = Car(
                id: carPayload.id,
                brand: carPayload.brand,
                modelName: carPayload.modelName,
                mileage: carPayload.mileage,
                purchaseDate: parsedCarPurchaseDate,
                disabledItemIDsRaw: carPayload.disabledItemIDsRaw
            )
            modelContext.insertWithAudit(car)
            summary.insertedCars += 1

            guard let profile = profileByKey[profileKey] else {
                throw NSError(
                    domain: "MyDataTransfer",
                    code: 1013,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(carPayload.brand) \(carPayload.modelName)”缺少保养项目配置。"]
                )
            }

            var optionsByName: [String: MaintenanceItemOption] = [:]
            var profileItemNames = Set<String>()
            for item in profile.serviceItems {
                let normalizedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard normalizedName.isEmpty == false else {
                    throw NSError(
                        domain: "MyDataTransfer",
                        code: 1008,
                        userInfo: [NSLocalizedDescriptionKey: "恢复失败：保养项目名称不能为空。"]
                    )
                }
                if profileItemNames.contains(normalizedName) {
                    throw NSError(
                        domain: "MyDataTransfer",
                        code: 1009,
                        userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(profile.brand) \(profile.modelName)”存在重复项目“\(normalizedName)”。"]
                    )
                }
                profileItemNames.insert(normalizedName)

                let option = MaintenanceItemOption(
                    id: item.id,
                    name: normalizedName,
                    ownerCarID: car.id,
                    isDefault: item.isDefault,
                    catalogKey: item.catalogKey,
                    remindByMileage: item.remindByMileage,
                    mileageInterval: item.mileageInterval,
                    remindByTime: item.remindByTime,
                    monthInterval: item.monthInterval,
                    warningStartPercent: item.warningStartPercent,
                    dangerStartPercent: item.dangerStartPercent,
                    createdAt: Date(timeIntervalSince1970: item.createdAt)
                )
                modelContext.insertWithAudit(option)
                optionsByName[normalizedName] = option
                summary.insertedItems += 1
            }

            for logPayload in vehicle.serviceLogs {
                guard
                    let parsedLogDate = dateOnlyFormatter.date(from: logPayload.date),
                    dateOnlyFormatter.string(from: parsedLogDate) == logPayload.date
                else {
                    throw NSError(
                        domain: "MyDataTransfer",
                        code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "保养日期格式错误：\(logPayload.date)。请使用 yyyy-MM-dd。"]
                    )
                }
                if importedLogIDs.contains(logPayload.id) {
                    throw NSError(
                        domain: "MyDataTransfer",
                        code: 1005,
                        userInfo: [NSLocalizedDescriptionKey: "恢复失败：备份内保养记录ID \(logPayload.id.uuidString) 重复。"]
                    )
                }
                importedLogIDs.insert(logPayload.id)

                let itemIDs = try itemIDsForImport(
                    names: logPayload.itemNames,
                    optionsByName: optionsByName
                )
                let itemIDsRaw = CoreConfig.joinItemIDs(itemIDs)
                let newLog = MaintenanceRecord(
                    id: logPayload.id,
                    date: parsedLogDate,
                    itemIDsRaw: itemIDsRaw,
                    cost: logPayload.cost,
                    mileage: logPayload.mileage,
                    note: logPayload.note,
                    car: car
                )
                modelContext.insertWithAudit(newLog)
                CoreConfig.syncCycleAndRelations(for: newLog, in: modelContext)
                summary.insertedLogs += 1
            }
        }

        try modelContext.saveOrThrowAndLog("恢复数据写入数据库")
        return summary
    }

    /// 将导入项目名称映射为项目 ID；名称不存在时直接报错。
    func itemIDsForImport(
        names: [String],
        optionsByName: [String: MaintenanceItemOption]
    ) throws -> [UUID] {
        var seen = Set<String>()
        let normalizedNames = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .filter { name in
                if seen.contains(name) {
                    return false
                }
                seen.insert(name)
                return true
            }

        guard normalizedNames.isEmpty == false else {
            throw NSError(
                domain: "MaintenanceDataTransfer",
                code: 1006,
                userInfo: [NSLocalizedDescriptionKey: "恢复失败：保养项目不能为空。"]
            )
        }

        return try normalizedNames.map { name in
            if let existing = optionsByName[name] {
                return existing.id
            }
            throw NSError(
                domain: "MaintenanceDataTransfer",
                code: 1007,
                userInfo: [NSLocalizedDescriptionKey: "恢复失败：项目“\(name)”未在车型配置中声明。"]
            )
        }
    }
}
