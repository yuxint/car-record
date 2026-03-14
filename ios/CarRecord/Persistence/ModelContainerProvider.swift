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
            MaintenanceLog.self,
            FuelLog.self,
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

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            /// 当 SwiftData 因旧库结构不兼容而加载失败时，自动重建本地库避免应用启动崩溃。
            print("首次加载本地数据库失败，准备重建本地库：\(error)")
            do {
                try purgePersistentStoreFiles()
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("初始化本地数据库失败：\(error)")
            }
        }
    }

    /// 清理应用容器内的本地数据库文件，重建时避免继续读取到旧结构。
    private static func purgePersistentStoreFiles() throws {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        let removableSuffixes = [
            ".store",
            ".store-shm",
            ".store-wal",
            ".sqlite",
            ".sqlite-shm",
            ".sqlite-wal",
        ]

        guard let enumerator = fileManager.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent.lowercased()
            guard removableSuffixes.contains(where: { fileName.hasSuffix($0) }) else {
                continue
            }
            try fileManager.removeItem(at: fileURL)
        }
    }
}
