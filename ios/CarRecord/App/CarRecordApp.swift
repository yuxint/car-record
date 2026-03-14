import SwiftUI
import SwiftData

/// 应用入口：统一注入 SwiftData 容器，保证全局读写本地数据。
@main
struct CarRecordApp: App {
    private let modelContainer = ModelContainerProvider.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
