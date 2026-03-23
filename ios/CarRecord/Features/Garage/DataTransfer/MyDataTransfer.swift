import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MyDataTransferPayload: Codable {
    var modelProfiles: [MyDataTransferModelProfilePayload]
    var vehicles: [MyDataTransferVehiclePayload]
}

/// 车型保养配置快照：按品牌+车型持久化项目配置。
struct MyDataTransferModelProfilePayload: Codable {
    var brand: String
    var modelName: String
    var serviceItems: [MyDataTransferItemPayload]
}

/// 保养项目快照：恢复时先重建项目配置，再重建保养记录。
struct MyDataTransferItemPayload: Codable {
    var id: UUID
    var name: String
    var isDefault: Bool
    var catalogKey: String?
    var remindByMileage: Bool
    var mileageInterval: Int
    var remindByTime: Bool
    var monthInterval: Int
    var warningStartPercent: Int
    var dangerStartPercent: Int
    var createdAt: TimeInterval
}

/// 单车备份恢复节点：车辆基础信息 + 该车辆下全部保养记录。
struct MyDataTransferVehiclePayload: Codable {
    var car: MyDataTransferCarPayload
    var serviceLogs: [MyDataTransferLogPayload]
}

/// 车辆基础信息快照。
struct MyDataTransferCarPayload: Codable {
    var id: UUID
    var brand: String
    var modelName: String
    var mileage: Int
    var disabledItemIDsRaw: String
    /// 仅保存日期，不保存时间与时区。
    var purchaseDate: String
}

/// 保养记录快照：项目以名称数组保存，导入时再映射到本地项目ID。
struct MyDataTransferLogPayload: Codable {
    var id: UUID
    /// 仅保存日期，不保存时间与时区。
    var date: String
    var itemNames: [String]
    var cost: Double
    var mileage: Int
    var note: String
}

/// 导入统计：用于导入结束后统一反馈。
struct MyDataTransferImportSummary {
    var insertedItems = 0
    var insertedCars = 0
    var insertedLogs = 0

    var message: String {
        "恢复完成：恢复项目\(insertedItems)项，恢复车辆\(insertedCars)辆，恢复保养记录\(insertedLogs)条。"
    }
}

/// 编解码器：统一 JSON 编解码配置；日期字段均使用 yyyy-MM-dd 字符串。
enum MyDataTransferCodec {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

/// 文件文档封装：把备份恢复 JSON 接入 SwiftUI 的 `fileExporter/fileImporter`。
struct MyDataTransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

/// “新增/编辑车辆”页面路由：避免首次打开编辑页时状态不同步。
enum CarFormTarget: Identifiable, Hashable {
    case add
    case edit(Car)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let car):
            return "edit-\(car.id.uuidString)"
        }
    }

    static func == (lhs: CarFormTarget, rhs: CarFormTarget) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
