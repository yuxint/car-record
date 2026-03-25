import Foundation
import SwiftData

extension MyView {
    func importMaintenanceData(from url: URL) {
        AppLogger.info("开始恢复数据", payload: url.lastPathComponent)
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try MyDataTransferCodec.decoder.decode(
                MyDataTransferPayload.self,
                from: data
            )
            try clearAllBusinessData()
            let summary = try applyImportedPayload(payload)
            presentTransferResult(summary.message)
        } catch {
            modelContext.rollback()
            AppLogger.error("恢复失败", payload: error.localizedDescription)
            presentTransferResult("恢复失败：请确认备份文件完整且结构正确。")
        }
    }
}
