import SwiftUI
import SwiftData

/// 保养提醒页：按"车辆 x 保养项目"展示下次保养进度百分比（时间/里程先到为准）。
struct MaintenanceReminderView: View {
    @Query var cars: [Car]
    @Query var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward)
    var serviceItemOptions: [MaintenanceItemOption]

    @StateObject var viewModel = MaintenanceReminderViewModel()
    @State var isAddingMaintenanceRecord = false

    private var scopedCars: [Car] {
        viewModel.scopedCars(cars: cars)
    }

    private var carSection: MaintenanceReminderCarSection? {
        viewModel.carSection(
            cars: cars,
            serviceRecords: serviceRecords,
            serviceItemOptions: serviceItemOptions
        )
    }

    var body: some View {
        List {
            if let section = carSection {
                Section(section.title) {
                    ForEach(section.rows) { row in
                        reminderRow(row)
                    }
                }
            } else if scopedCars.isEmpty == false {
                Section(CarDisplayFormatter.name(scopedCars[0])) {
                    Text("暂无保养记录，完成保养后开始提醒。")
                        .foregroundStyle(.secondary)
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
            viewModel.syncAppliedCarSelection(cars: cars)
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            viewModel.syncAppliedCarSelection(cars: cars)
        }
    }
}

private extension MaintenanceReminderView {
    @ViewBuilder
    func reminderRow(_ row: MaintenanceReminderRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.itemName)
                    .lineLimit(1)
                Spacer()
                Text(row.progressText)
                    .fontWeight(.semibold)
                    .foregroundStyle(row.progressColorLevel.color)
            }

            LinearProgressBar(
                value: row.displayProgress,
                color: row.progressColorLevel.color
            )

            ForEach(Array(row.detailTexts.enumerated()), id: \.offset) { _, detailText in
                Text(detailText)
                    .font(.footnote)
                    .foregroundStyle(row.progressColorLevel.secondaryColor)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension ReminderProgressColorLevel {
    var color: Color {
        switch self {
        case .normal:
            return .green
        case .warning:
            return .yellow
        case .danger:
            return .red
        }
    }

    var secondaryColor: Color {
        .secondary
    }
}

/// 自绘进度条：在 0% 时只显示背景，不渲染前景色填充。
private struct LinearProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                if clampedValue > 0 {
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * clampedValue)
                }
            }
        }
        .frame(height: 8)
    }

    var clampedValue: Double {
        min(max(value, 0), 1)
    }
}
