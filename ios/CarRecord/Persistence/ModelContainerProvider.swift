import Foundation
import SwiftData

/// SwiftData 容器工厂：统一管理持久化和内存模式。
enum ModelContainerProvider {
    /// 默认持久化模式（落盘到设备本地）。
    static func makeDefault() -> ModelContainer {
        build(isStoredInMemoryOnly: false)
    }

    /// 仅内存模式（用于预览或测试）。
    static func makeInMemory() -> ModelContainer {
        build(isStoredInMemoryOnly: true)
    }

    private static func build(isStoredInMemoryOnly: Bool) -> ModelContainer {
        let schema = Schema([
            Car.self,
            MaintenanceRecord.self,
            MaintenanceRecordItem.self,
            MaintenanceItemOption.self,
        ])

        if isStoredInMemoryOnly {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("初始化本地数据库失败：\(error)")
            }
        }

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("初始化本地数据库失败：\(error)")
        }
    }
}

/// ModelContext 保存工具：统一收敛保存失败日志，避免各页面静默吞错。
extension ModelContext {
    @discardableResult
    func saveOrLog(_ action: String) -> String? {
        do {
            try save()
            return nil
        } catch {
            print("\(action)失败：\(error)")
            return userFacingSaveErrorMessage(for: action, error: error)
        }
    }

    /// 统一用户可读错误文案：不暴露底层日志，仅给出可执行的提示。
    private func userFacingSaveErrorMessage(for action: String, error: Error) -> String {
        let message = (error as NSError).localizedDescription.lowercased()
        if message.contains("unique") || message.contains("constraint") || message.contains("duplicate") {
            return "\(action)失败：存在重复数据，请检查同车同日记录、项目名称或车辆信息。"
        }
        return "\(action)失败，请稍后重试。"
    }
} 
