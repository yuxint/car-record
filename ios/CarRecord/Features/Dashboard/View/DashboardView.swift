import SwiftUI
import SwiftData

/// 概览页：按“车辆 x 保养项目”展示下次保养进度百分比（时间/里程先到为准）。
struct DashboardView: View {
    @Query var cars: [Car]
    @Query var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward)
    var serviceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) var appliedCarIDRaw = ""
    @State var isAddingMaintenanceRecord = false

    var body: some View {
        List {
            if cars.isEmpty {
                Text("请先在“我的”中添加车辆。")
                    .foregroundStyle(.secondary)
            } else if carSections.isEmpty {
                Text("暂无保养记录，完成首次保养后开始提醒。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(carSections) { section in
                    Section(section.title) {
                        ForEach(section.rows) { row in
                            reminderRow(row)
                        }
                    }
                }
            }
        }
        .navigationTitle("概览")
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
        .sheet(isPresented: $isAddingMaintenanceRecord) {
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
