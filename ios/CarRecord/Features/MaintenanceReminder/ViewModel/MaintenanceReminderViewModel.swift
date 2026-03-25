import Foundation
import Combine
import SwiftUI

@MainActor
final class MaintenanceReminderViewModel: ObservableObject {
    @Published private(set) var appliedCarIDRaw: String {
        didSet {
            UserDefaults.standard.set(appliedCarIDRaw, forKey: AppliedCarContext.storageKey)
        }
    }

    init() {
        appliedCarIDRaw = UserDefaults.standard.string(forKey: AppliedCarContext.storageKey) ?? ""
    }
}

extension MaintenanceReminderViewModel {
    func appliedCarID(cars: [Car]) -> UUID? {
        AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars)
    }

    func scopedCars(cars: [Car]) -> [Car] {
        guard let appliedCarID = appliedCarID(cars: cars) else { return [] }
        return cars.filter { $0.id == appliedCarID }
    }

    func scopedMaintenanceRecords(cars: [Car], serviceRecords: [MaintenanceRecord]) -> [MaintenanceRecord] {
        guard let appliedCarID = appliedCarID(cars: cars) else { return [] }
        return serviceRecords.filter { $0.car?.id == appliedCarID }
    }

    func syncAppliedCarSelection(cars: [Car]) {
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    func carSection(
        cars: [Car],
        serviceRecords: [MaintenanceRecord],
        serviceItemOptions: [MaintenanceItemOption]
    ) -> MaintenanceReminderCarSection? {
        let scopedCars = scopedCars(cars: cars)
        let scopedMaintenanceRecords = scopedMaintenanceRecords(cars: cars, serviceRecords: serviceRecords)
        guard let car = scopedCars.first, scopedMaintenanceRecords.min(by: { $0.date < $1.date }) != nil else {
            return nil
        }

        let options = sortedMaintenanceItemOptions(cars: cars, serviceItemOptions: serviceItemOptions)
        let logIndex = scopedMaintenanceRecords.reduce(into: [String: MaintenanceRecord]()) { partialResult, record in
            let index = MaintenanceReminderRules.buildLatestLogIndex(record: record)
            for (key, value) in index {
                if let existing = partialResult[key] {
                    if existing.date > value.date {
                        continue
                    }
                    if existing.date == value.date, existing.mileage >= value.mileage {
                        continue
                    }
                }
                partialResult[key] = value
            }
        }

        let now = AppDateContext.now()
        let rows = options.map { option in
            let key = MaintenanceReminderRules.latestLogKey(carID: car.id, itemID: option.id)
            return MaintenanceReminderRules.buildReminderRow(
                car: car,
                option: option,
                itemLatestLog: logIndex[key],
                now: now,
                calendar: .current
            )
        }
        .sorted { lhs, rhs in
            if lhs.rawProgress != rhs.rawProgress {
                return lhs.rawProgress > rhs.rawProgress
            }
            if lhs.duePriority != rhs.duePriority {
                return lhs.duePriority < rhs.duePriority
            }
            return lhs.itemName < rhs.itemName
        }

        return MaintenanceReminderCarSection(
            id: car.id,
            title: CarDisplayFormatter.name(car),
            rows: rows
        )
    }

    func sortedMaintenanceItemOptions(cars: [Car], serviceItemOptions: [MaintenanceItemOption]) -> [MaintenanceItemOption] {
        let scopedCar = scopedCars(cars: cars).first
        let visibleOptions = CoreConfig.filterDisabledOptions(
            CoreConfig.scopedOptions(serviceItemOptions, carID: appliedCarID(cars: cars)),
            disabledItemIDsRaw: scopedCar?.disabledItemIDsRaw ?? "",
            includeDisabled: false
        )
        return CoreConfig.sortedOptions(
            visibleOptions,
            brand: scopedCar?.brand,
            modelName: scopedCar?.modelName
        )
    }
}
