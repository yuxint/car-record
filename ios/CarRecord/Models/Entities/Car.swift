import Foundation
import SwiftData

/// 车辆主实体：一辆车对应多条保养记录。
@Model
final class Car {
    @Attribute(.unique) var id: UUID
    var brand: String
    var modelName: String
    var mileage: Int
    var purchaseDate: Date

    /// 关联保养记录，删除车辆时级联删除，避免脏数据残留。
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRecord.car)
    var serviceRecords: [MaintenanceRecord]

    init(
        id: UUID = UUID(),
        brand: String,
        modelName: String,
        mileage: Int,
        purchaseDate: Date
    ) {
        self.id = id
        self.brand = brand
        self.modelName = modelName
        self.mileage = mileage
        self.purchaseDate = purchaseDate
        self.serviceRecords = []
    }
}
