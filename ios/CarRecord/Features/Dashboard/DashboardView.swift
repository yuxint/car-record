import SwiftUI
import SwiftData

/// 仪表盘：聚合本地数据，展示总览统计，不依赖网络接口。
struct DashboardView: View {
    @Query private var cars: [Car]
    @Query private var maintenanceLogs: [MaintenanceLog]
    @Query private var fuelLogs: [FuelLog]

    /// 保养累计费用（本地计算）。
    private var totalMaintenanceCost: Double {
        maintenanceLogs.reduce(0) { $0 + $1.cost }
    }

    /// 加油累计费用（本地计算）。
    private var totalFuelCost: Double {
        fuelLogs.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        List {
            Section("总览") {
                summaryRow(title: "车辆数", value: "\(cars.count)")
                summaryRow(title: "保养总费用", value: CurrencyFormatter.value(totalMaintenanceCost))
                summaryRow(title: "加油总费用", value: CurrencyFormatter.value(totalFuelCost))
                summaryRow(title: "记录总数", value: "\(maintenanceLogs.count + fuelLogs.count)")
            }

            Section("提示") {
                Text("每次保养后记得更新里程。")
                Text("建议按次记录加油，方便观察用车成本变化。")
            }
        }
        .navigationTitle("概览")
    }

    @ViewBuilder
    /// 通用统计行，减少重复 UI 代码。
    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
