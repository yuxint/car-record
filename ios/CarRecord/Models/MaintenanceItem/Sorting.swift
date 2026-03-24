import Foundation

extension CoreConfig {
    /// 项目作用域过滤：所有项目都只对归属车辆可见。
    static func scopedOptions(
        _ options: [MaintenanceItemOption],
        carID: UUID?
    ) -> [MaintenanceItemOption] {
        options.filter { option in
            guard let carID else { return false }
            return option.ownerCarID == carID
        }
    }

    /// 统一排序：仅按车型默认项目顺序。
    static func sortedOptions(
        _ options: [MaintenanceItemOption],
        brand: String?,
        modelName: String?
    ) -> [MaintenanceItemOption] {
        let orderByKey = modelConfig(brand: brand, modelName: modelName).defaultOrderByKey
        return options
            .enumerated()
            .sorted { lhs, rhs in
                let lhsOrder = orderByKey[lhs.element.catalogKey ?? ""] ?? Int.max
                let rhsOrder = orderByKey[rhs.element.catalogKey ?? ""] ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
