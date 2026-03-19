import SwiftUI

/// 根导航：按"保养提醒-记录-我的"拆分主流程，"我的"固定在第 3 个标签。
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
