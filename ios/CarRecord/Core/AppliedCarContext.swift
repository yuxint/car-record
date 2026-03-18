import Foundation
import SwiftData

/// 已应用车型上下文：统一管理“当前应用车辆”的本地持久化与回退策略。
enum AppliedCarContext {
    static let storageKey = "applied_car_id"

    /// 解析持久化字符串为车辆ID；空串或非法值都按未设置处理。
    static func decodeCarID(from rawID: String) -> UUID? {
        let normalized = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return nil }
        return UUID(uuidString: normalized)
    }

    /// 编码车辆ID为持久化字符串；空值统一写入空串。
    static func encodeCarID(_ carID: UUID?) -> String {
        carID?.uuidString ?? ""
    }

    /// 解析当前可用的应用车型ID；若原ID失效则自动回退到第一辆车。
    static func resolveAppliedCarID(rawID: String, cars: [Car]) -> UUID? {
        if let preferredID = decodeCarID(from: rawID),
           cars.contains(where: { $0.id == preferredID }) {
            return preferredID
        }
        return cars.first?.id
    }

    /// 规范化持久化值：保证写回后一定是“有效ID或空串”。
    static func normalizedRawID(rawID: String, cars: [Car]) -> String {
        let resolvedID = resolveAppliedCarID(rawID: rawID, cars: cars)
        return encodeCarID(resolvedID)
    }
}
