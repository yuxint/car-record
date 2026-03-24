import SwiftUI
import SwiftData

/// 保养提醒页：按"车辆 x 保养项目"展示下次保养进度百分比（时间/里程先到为准）。
struct MaintenanceReminderView: View {
    @Query var cars: [Car]
    @Query var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward)
    var serviceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) var appliedCarIDRaw = ""
    @State var isAddingMaintenanceRecord = false

    var body: some View {
        List {
            if let appliedCar = scopedCars.first {
                Section(CarDisplayFormatter.name(appliedCar)) {
                    if carSection == nil {
                        Text("暂无保养记录，完成首次保养后开始提醒。")
                            .foregroundStyle(.secondary)
                    } else if let section = carSection {
                        ForEach(section.rows) { row in
                            reminderRow(row)
                        }
                    }
                }
            } else if cars.isEmpty {
                Text("请先在\"个人中心\"中添加车辆。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("保养提醒")
        .toolbar(isAddingMaintenanceRecord ? .hidden : .visible, for: .tabBar)
        .animation(.none, value: isAddingMaintenanceRecord)
        .toolbar {
            /// 无车辆时隐藏新增入口，避免进入无效新增流程。
            if scopedCars.isEmpty == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingMaintenanceRecord = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isAddingMaintenanceRecord) {
            AddMaintenanceRecordView()
        }
        .onAppear {
            syncAppliedCarSelection()
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            syncAppliedCarSelection()
        }
    }
}
