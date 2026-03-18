import Foundation
import SwiftData

/// 保养记录实体：记录项目、费用、里程并绑定所属车辆。
@Model
final class MaintenanceRecord {
    @Attribute(.unique) var id: UUID
    /// 周期唯一键：`carID + yyyy-MM-dd`，用于数据库层约束“同车同日唯一”。
    @Attribute(.unique) var cycleKey: String?
    /// 周期项目关系：用于数据库层约束“同车同日同项目唯一”。
    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRecordItem.record) var itemRelations: [MaintenanceRecordItem]
    var date: Date
    /// 保养项目ID列表（字符串持久化）：通过ID映射名称，避免改名影响引用。
    var itemIDsRaw: String
    var cost: Double
    var mileage: Int
    var note: String
    var car: Car?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        itemIDsRaw: String,
        cost: Double,
        mileage: Int,
        note: String = "",
        car: Car
    ) {
        self.id = id
        self.cycleKey = Self.cycleKey(carID: car.id, date: date)
        self.itemRelations = []
        self.date = date
        self.itemIDsRaw = itemIDsRaw
        self.cost = cost
        self.mileage = mileage
        self.note = note
        self.car = car
    }

    /// 生成“同车同日”唯一键，日期统一按 yyyy-MM-dd 落键。
    static func cycleKey(carID: UUID, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        let day = formatter.string(from: Calendar.current.startOfDay(for: date))
        return "\(carID.uuidString)|\(day)"
    }
}
