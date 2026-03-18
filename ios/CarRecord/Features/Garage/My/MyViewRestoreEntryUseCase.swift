import Foundation
import SwiftData

extension MyView {
    func importMaintenanceData(from url: URL) {
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
            presentTransferResult("恢复失败：请确认备份文件完整且结构正确。")
        }
    }
}
