import SwiftUI

/// 根导航：按“概览-记录-我的”拆分主流程，“我的”固定在第 3 个标签。
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("概览", systemImage: "speedometer")
            }

            NavigationStack {
                LogsView()
            }
            .tabItem {
                Label("记录", systemImage: "list.bullet.clipboard")
            }

            NavigationStack {
                MyView()
            }
            .tabItem {
                Label("我的", systemImage: "person.circle.fill")
            }
        }
    }
}
