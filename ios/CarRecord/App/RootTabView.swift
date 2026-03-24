import SwiftUI

/// 根导航：按"保养提醒-保养记录-个人中心"拆分主流程，"个人中心"固定在第 3 个标签。
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                MaintenanceReminderView()
            }
            .tabItem {
                Label("保养提醒", systemImage: "speedometer")
            }

            NavigationStack {
                RecordsView()
            }
            .tabItem {
                Label("保养记录", systemImage: "list.bullet.clipboard")
            }

            NavigationStack {
                MyView()
            }
            .tabItem {
                Label("个人中心", systemImage: "person.circle.fill")
            }
        }
    }
}
