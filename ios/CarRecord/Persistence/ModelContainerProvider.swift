import Foundation
import SwiftData

enum AppLogLevel: String, CaseIterable {
    case info
    case warn
    case error

    var displayTitle: String {
        switch self {
        case .info:
            return "INFO"
        case .warn:
            return "WARN"
        case .error:
            return "ERROR"
        }
    }
}

actor AppLogFileStore {
    static let shared = AppLogFileStore()

    private let fileManager = FileManager.default
    private let maxFileSizeInBytes = 10 * 1024 * 1024

    private var logsDirectoryURL: URL {
        let root = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return root.appendingPathComponent("logs", isDirectory: true)
    }

    private var logFileURL: URL {
        logsDirectoryURL.appendingPathComponent("app.log")
    }

    func filePath() -> String {
        logFileURL.path
    }

    func appendLine(_ line: String) {
        ensureDirectoryIfNeeded()

        if fileManager.fileExists(atPath: logFileURL.path) == false {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }

        guard let newLineData = "\(line)\n".data(using: .utf8) else { return }
        do {
            var currentData = (try? Data(contentsOf: logFileURL)) ?? Data()
            currentData.append(newLineData)

            if currentData.count > maxFileSizeInBytes {
                currentData = Data(currentData.suffix(maxFileSizeInBytes))
                if let firstNewLineIndex = currentData.firstIndex(of: 0x0A),
                   firstNewLineIndex < currentData.endIndex - 1 {
                    currentData.removeSubrange(currentData.startIndex...firstNewLineIndex)
                }
            }

            try currentData.write(to: logFileURL, options: .atomic)
        } catch {
            print("[ERROR] 日志文件写入失败：\(error.localizedDescription)")
        }
    }

    func readAll() -> String {
        ensureDirectoryIfNeeded()
        guard fileManager.fileExists(atPath: logFileURL.path) else { return "" }
        guard let data = try? Data(contentsOf: logFileURL) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    func clear() {
        ensureDirectoryIfNeeded()
        do {
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("[ERROR] 日志文件清空失败：\(error.localizedDescription)")
        }
    }

    func currentFileSizeInBytes() -> Int {
        let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path)
        let currentFileSize = attributes?[.size] as? NSNumber
        return currentFileSize?.intValue ?? 0
    }

    private func ensureDirectoryIfNeeded() {
        if fileManager.fileExists(atPath: logsDirectoryURL.path) { return }
        try? fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
    }

}

enum AppLogger {
    static func info(
        _ message: String,
        payload: Any? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        append(level: .info, message: message, payload: payload, file: file, function: function, line: line)
    }

    static func warn(
        _ message: String,
        payload: Any? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        append(level: .warn, message: message, payload: payload, file: file, function: function, line: line)
    }

    static func error(
        _ message: String,
        payload: Any? = nil,
        includeStack: Bool = true,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        append(
            level: .error,
            message: message,
            payload: payload,
            includeStack: includeStack,
            file: file,
            function: function,
            line: line
        )
    }

    private static func append(
        level: AppLogLevel,
        message: String,
        payload: Any? = nil,
        includeStack: Bool = false,
        file: String,
        function: String,
        line: Int
    ) {
        let formattedLine = formatLine(
            level: level,
            message: message,
            payload: payload,
            includeStack: includeStack,
            file: file,
            function: function,
            line: line
        )
        print(formattedLine)
        Task {
            await AppLogFileStore.shared.appendLine(formattedLine)
        }
    }

    private static func formatLine(
        level: AppLogLevel,
        message: String,
        payload: Any?,
        includeStack: Bool,
        file: String,
        function: String,
        line: Int
    ) -> String {
        let timestamp = AppDateContext.makeDisplayFormatter("yyyy-MM-dd HH:mm:ss.SSS").string(from: Date())
        var fields: [String] = [
            timestamp,
            "[\(level.displayTitle)]",
            "[\(file):\(line)]",
            "[\(function)]",
            message
        ]

        if let payload {
            fields.append("payload=\(String(describing: payload))")
        }

        if includeStack {
            let stack = Thread.callStackSymbols
                .dropFirst(2)
                .prefix(8)
                .joined(separator: " <- ")
            fields.append("stack=\(stack)")
        }

        return fields.joined(separator: " ")
    }
}

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
            AppLogger.info("\(action)成功")
            return nil
        } catch {
            AppLogger.error("\(action)失败", payload: error.localizedDescription)
            return userFacingSaveErrorMessage(for: action, error: error)
        }
    }

    func saveOrThrowAndLog(_ action: String) throws {
        do {
            try save()
            AppLogger.info("\(action)成功")
        } catch {
            AppLogger.error("\(action)失败", payload: error.localizedDescription)
            throw error
        }
    }

    func insertWithAudit(_ car: Car) {
        insert(car)
        AppDatabaseAuditLogger.logInsert(entity: "Car", data: AppDatabaseSnapshot.car(car))
    }

    func insertWithAudit(_ option: MaintenanceItemOption) {
        insert(option)
        AppDatabaseAuditLogger.logInsert(entity: "MaintenanceItemOption", data: AppDatabaseSnapshot.maintenanceItemOption(option))
    }

    func insertWithAudit(_ record: MaintenanceRecord) {
        insert(record)
        AppDatabaseAuditLogger.logInsert(entity: "MaintenanceRecord", data: AppDatabaseSnapshot.maintenanceRecord(record))
    }

    func insertWithAudit(_ relation: MaintenanceRecordItem) {
        insert(relation)
        AppDatabaseAuditLogger.logInsert(entity: "MaintenanceRecordItem", data: AppDatabaseSnapshot.maintenanceRecordItem(relation))
    }

    func deleteWithAudit(_ car: Car) {
        AppDatabaseAuditLogger.logDelete(entity: "Car", data: AppDatabaseSnapshot.car(car))
        delete(car)
    }

    func deleteWithAudit(_ option: MaintenanceItemOption) {
        AppDatabaseAuditLogger.logDelete(entity: "MaintenanceItemOption", data: AppDatabaseSnapshot.maintenanceItemOption(option))
        delete(option)
    }

    func deleteWithAudit(_ record: MaintenanceRecord) {
        AppDatabaseAuditLogger.logDelete(entity: "MaintenanceRecord", data: AppDatabaseSnapshot.maintenanceRecord(record))
        delete(record)
    }

    func deleteWithAudit(_ relation: MaintenanceRecordItem) {
        AppDatabaseAuditLogger.logDelete(entity: "MaintenanceRecordItem", data: AppDatabaseSnapshot.maintenanceRecordItem(relation))
        delete(relation)
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

enum AppDatabaseAuditLogger {
    static func logInsert(entity: String, data: [String: Any]) {
        AppLogger.info("数据库新增", payload: makePayload(action: "insert", entity: entity, data: data))
    }

    static func logDelete(entity: String, data: [String: Any]) {
        AppLogger.info("数据库删除", payload: makePayload(action: "delete", entity: entity, data: data))
    }

    static func logUpdate(entity: String, before: [String: Any], after: [String: Any]) {
        let payload = makePayload(
            action: "update",
            entity: entity,
            data: [
                "before": before,
                "after": after,
            ]
        )
        AppLogger.info("数据库修改", payload: payload)
    }

    private static func makePayload(action: String, entity: String, data: [String: Any]) -> String {
        let payload: [String: Any] = [
            "action": action,
            "entity": entity,
            "data": data,
        ]
        return jsonString(from: payload)
    }

    private static func jsonString(from dictionary: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(dictionary),
              let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
              let text = String(data: jsonData, encoding: .utf8)
        else {
            return String(describing: dictionary)
        }
        return text
    }
}

enum AppDatabaseSnapshot {
    static func car(_ car: Car) -> [String: Any] {
        [
            "id": car.id.uuidString,
            "brand": car.brand,
            "modelName": car.modelName,
            "mileage": car.mileage,
            "purchaseDate": dateString(car.purchaseDate),
            "disabledItemIDsRaw": car.disabledItemIDsRaw,
        ]
    }

    static func maintenanceItemOption(_ option: MaintenanceItemOption) -> [String: Any] {
        [
            "id": option.id.uuidString,
            "name": option.name,
            "ownerCarID": nullable(option.ownerCarID?.uuidString),
            "isDefault": option.isDefault,
            "catalogKey": nullable(option.catalogKey),
            "remindByMileage": option.remindByMileage,
            "mileageInterval": option.mileageInterval,
            "remindByTime": option.remindByTime,
            "monthInterval": option.monthInterval,
            "warningStartPercent": option.warningStartPercent,
            "dangerStartPercent": option.dangerStartPercent,
            "createdAt": dateString(option.createdAt),
        ]
    }

    static func maintenanceRecord(_ record: MaintenanceRecord) -> [String: Any] {
        [
            "id": record.id.uuidString,
            "cycleKey": nullable(record.cycleKey),
            "date": dateString(record.date),
            "itemIDsRaw": record.itemIDsRaw,
            "cost": record.cost,
            "mileage": record.mileage,
            "note": record.note,
            "carID": nullable(record.car?.id.uuidString),
        ]
    }

    static func maintenanceRecordItem(_ relation: MaintenanceRecordItem) -> [String: Any] {
        [
            "id": relation.id.uuidString,
            "cycleItemKey": nullable(relation.cycleItemKey),
            "itemID": relation.itemID.uuidString,
            "createdAt": dateString(relation.createdAt),
            "recordID": nullable(relation.record?.id.uuidString),
        ]
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func nullable(_ value: String?) -> Any {
        value ?? NSNull()
    }
}
