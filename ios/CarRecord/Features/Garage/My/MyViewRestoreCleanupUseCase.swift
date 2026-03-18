import SwiftData

extension MyView {
    func clearAllBusinessData() throws {
        let allCars = try modelContext.fetch(FetchDescriptor<Car>())
        for car in allCars {
            modelContext.delete(car)
        }

        let allMaintenanceItems = try modelContext.fetch(FetchDescriptor<MaintenanceItemOption>())
        for item in allMaintenanceItems {
            modelContext.delete(item)
        }

        let allLogs = try modelContext.fetch(FetchDescriptor<MaintenanceRecord>())
        for log in allLogs {
            modelContext.delete(log)
        }

        try modelContext.save()
        appliedCarIDRaw = ""
    }
}
