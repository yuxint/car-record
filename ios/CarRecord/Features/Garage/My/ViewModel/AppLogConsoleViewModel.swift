import Foundation
import Combine
import SwiftUI

@MainActor
final class AppLogConsoleViewModel: ObservableObject {
    @Published var logFilePath = ""
    @Published var logFileSize = 0
    @Published var logContent = ""

    var parsedLines: [String] {
        Array(
            logContent
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .filter { $0.isEmpty == false }
                .reversed()
        )
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(logFileSize), countStyle: .file)
    }

    func reloadLogFile() async {
        let path = await AppLogFileStore.shared.filePath()
        let content = await AppLogFileStore.shared.readAll()
        let size = await AppLogFileStore.shared.currentFileSizeInBytes()
        logFilePath = path
        logFileSize = size
        logContent = content
    }

    func clearAndReload() async {
        await AppLogFileStore.shared.clear()
        await reloadLogFile()
    }

    func color(for line: String) -> Color {
        if line.contains("[ERROR]") {
            return .red
        }
        if line.contains("[WARN]") {
            return .yellow
        }
        if line.contains("[INFO]") {
            return .black
        }
        return .primary
    }
}
