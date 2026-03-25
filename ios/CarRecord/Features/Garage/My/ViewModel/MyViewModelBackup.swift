import SwiftUI
import SwiftData

extension MyView {
    func startBackupData() {
        AppLogger.info(
            "开始备份数据",
            payload: "cars=\(cars.count), records=\(serviceRecords.count), items=\(serviceItemOptions.count)"
        )
        var logsByCarID: [UUID: [MaintenanceRecord]] = [:]
        for log in serviceRecords {
            guard let carID = log.car?.id else { continue }
            logsByCarID[carID, default: []].append(log)
        }
        let vehicles = cars.map { car in
            let relatedLogs = (logsByCarID[car.id] ?? [])
                .sorted { lhs, rhs in
                    if lhs.date != rhs.date {
                        return lhs.date < rhs.date
                    }
                    return lhs.mileage < rhs.mileage
                }

            let carPayload = MyDataTransferCarPayload(
                id: car.id,
                brand: car.brand,
                modelName: car.modelName,
                mileage: car.mileage,
                disabledItemIDsRaw: car.disabledItemIDsRaw,
                purchaseDate: exportDateString(car.purchaseDate)
            )

            let logPayloads = relatedLogs.map { log in
                MyDataTransferLogPayload(
                    id: log.id,
                    date: exportDateString(log.date),
                    itemNames: CoreConfig.exportItemNames(
                        from: log.itemIDsRaw,
                        options: CoreConfig.scopedOptions(serviceItemOptions, carID: car.id)
                    ),
                    cost: log.cost,
                    mileage: log.mileage,
                    note: log.note
                )
            }

            return MyDataTransferVehiclePayload(
                car: carPayload,
                serviceLogs: logPayloads
            )
        }

        var modelKeys = Set<String>()
        let modelProfiles = cars.compactMap { car -> MyDataTransferModelProfilePayload? in
            let key = modelProfileKey(brand: car.brand, modelName: car.modelName)
            if modelKeys.contains(key) {
                return nil
            }
            modelKeys.insert(key)
            return MyDataTransferModelProfilePayload(
                brand: car.brand,
                modelName: car.modelName,
                serviceItems: CoreConfig.scopedOptions(serviceItemOptions, carID: car.id).map { option in
                    MyDataTransferItemPayload(
                        id: option.id,
                        name: option.name,
                        isDefault: option.isDefault,
                        catalogKey: option.catalogKey,
                        remindByMileage: option.remindByMileage,
                        mileageInterval: option.mileageInterval,
                        remindByTime: option.remindByTime,
                        monthInterval: option.monthInterval,
                        warningStartPercent: option.warningStartPercent,
                        dangerStartPercent: option.dangerStartPercent,
                        createdAt: option.createdAt.timeIntervalSince1970
                    )
                }
            )
        }

        let payload = MyDataTransferPayload(
            modelProfiles: modelProfiles,
            vehicles: vehicles
        )
        guard let encodedData = try? MyDataTransferCodec.encoder.encode(payload) else {
            AppLogger.error(
                "备份失败：数据编码失败",
                payload: "vehicles=\(vehicles.count), modelProfiles=\(modelProfiles.count)",
                includeStack: false
            )
            presentTransferResult("备份失败：数据编码失败。")
            return
        }

        exportDocument = MyDataTransferDocument(data: encodedData)
        exportFilename = "car-record-backup-\(timestampForFilename(Date()))"
        isExportingMaintenanceData = true
        AppLogger.info(
            "备份数据编码完成",
            payload: "vehicles=\(vehicles.count), modelProfiles=\(modelProfiles.count)"
        )
    }
    func timestampForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    /// 导出统一日期格式：只保留"年-月-日"，与表单输入口径保持一致。
    func exportDateString(_ date: Date) -> String {
        AppDateContext.formatShortDate(date)
    }

}
