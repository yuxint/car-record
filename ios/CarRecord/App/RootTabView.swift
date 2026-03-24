import SwiftUI

/// 根导航：按"保养提醒-保养记录-个人中心"拆分主流程，"个人中心"固定在第 3 个标签。
struct RootTabView: View {
    enum Tab: Hashable {
        case reminder
        case records
        case my
    }

    @State private var selectedTab: Tab = .reminder
    @State private var reminderReloadID = 0
    @State private var recordsReloadID = 0
    @State private var myReloadID = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MaintenanceReminderView()
            }
            .id(reminderReloadID)
            .tag(Tab.reminder)
            .tabItem {
                Label("保养提醒", systemImage: "speedometer")
            }

            NavigationStack {
                RecordsView()
            }
            .id(recordsReloadID)
            .tag(Tab.records)
            .tabItem {
                Label("保养记录", systemImage: "list.bullet.clipboard")
            }

            NavigationStack {
                MyView()
            }
            .id(myReloadID)
            .tag(Tab.my)
            .tabItem {
                Label("个人中心", systemImage: "person.circle.fill")
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            switch newValue {
            case .reminder:
                reminderReloadID += 1
            case .records:
                recordsReloadID += 1
            case .my:
                myReloadID += 1
            }
        }
    }
}
