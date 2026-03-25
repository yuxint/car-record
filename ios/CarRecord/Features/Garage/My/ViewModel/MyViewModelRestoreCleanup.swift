import SwiftData

extension MyView {
    func clearAllBusinessData() throws {
        AppLogger.info("开始清空业务数据")
        let allCars = try modelContext.fetch(FetchDescriptor<Car>())
        let allCarIDs = allCars.map(\.id.uuidString)
        for car in allCars {
            modelContext.deleteWithAudit(car)
        }

        let allMaintenanceItems = try modelContext.fetch(FetchDescriptor<MaintenanceItemOption>())
        let allItemIDs = allMaintenanceItems.map(\.id.uuidString)
        for item in allMaintenanceItems {
            modelContext.deleteWithAudit(item)
        }

        let allLogs = try modelContext.fetch(FetchDescriptor<MaintenanceRecord>())
        let allLogIDs = allLogs.map(\.id.uuidString)
        for log in allLogs {
            modelContext.deleteWithAudit(log)
        }

        AppLogger.info(
            "清空业务数据明细",
            payload: "carIDs=\(allCarIDs), itemIDs=\(allItemIDs), logIDs=\(allLogIDs)"
        )

        try modelContext.saveOrThrowAndLog("清空业务数据")
        appliedCarIDRaw = ""
    }
}
