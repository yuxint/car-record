import Foundation
import SwiftData

/// 加油记录实体：用于后续油耗与用车成本统计。
@Model
final class FuelLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var liters: Double
    var amount: Double
    var mileage: Int
    var car: Car?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        liters: Double,
        amount: Double,
        mileage: Int,
        car: Car
    ) {
        self.id = id
        self.date = date
        self.liters = liters
        self.amount = amount
        self.mileage = mileage
        self.car = car
    }
}
