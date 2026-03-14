import SwiftUI
import SwiftData

/// 保养记录列表页：读取本地保养记录并支持新增。
struct LogsView: View {
    @Query(sort: \MaintenanceLog.date, order: .reverse)
    private var maintenanceLogs: [MaintenanceLog]

    @State private var displayMode: LogDisplayMode = .byDate
    @State private var isAddingLog = false
    @State private var editingLog: MaintenanceLog?

    var body: some View {
        List {
            Section {
                Picker("展示方式", selection: $displayMode) {
                    ForEach(LogDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if maintenanceLogs.isEmpty {
                Text("还没有保养记录。")
                    .foregroundStyle(.secondary)
            } else {
                if displayMode == .byDate {
                    Section("按日期展示") {
                        ForEach(dateGroups) { group in
                            dateGroupRow(group)
                        }
                    }
                } else {
                    Section("按保养项目展示") {
                        ForEach(itemRows) { row in
                            itemRow(row)
                        }
                    }
                }
            }
        }
        .navigationTitle("保养记录")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingLog = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingLog) {
            AddMaintenanceLogView()
        }
        .sheet(item: $editingLog) { log in
            AddMaintenanceLogView(editingLog: log)
        }
    }

    /// 按日期分组并倒序，自动合并同一天的保养记录。
    private var dateGroups: [MaintenanceDateGroup] {
        let grouped = Dictionary(grouping: maintenanceLogs) { log in
            Calendar.current.startOfDay(for: log.date)
        }

        return grouped
            .map { date, logs in
                MaintenanceDateGroup(
                    date: date,
                    logs: logs.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.date > $1.date }
    }

    /// 展开“按项目展示”时使用的行数据（按日期倒序）。
    private var itemRows: [MaintenanceItemRow] {
        maintenanceLogs.flatMap { log in
            let items = MaintenanceItemCatalog.parse(log.title)
            let normalizedItems = items.isEmpty ? ["未标注项目"] : items

            return normalizedItems.enumerated().map { index, item in
                MaintenanceItemRow(
                    id: "\(log.id.uuidString)-\(index)-\(item)",
                    item: item,
                    log: log
                )
            }
        }
        .sorted { $0.log.date > $1.log.date }
    }

    /// 日期维度的聚合卡片：单层展示，不使用展开折叠。
    @ViewBuilder
    private func dateGroupRow(_ group: MaintenanceDateGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateTextFormatter.shortDate(group.date))
                .font(.headline)
            Text(group.primaryLog.car.map { "\($0.brand) \($0.modelName)" } ?? "未知车辆")
                .foregroundStyle(.secondary)
            Text("里程：\(group.primaryLog.mileage) km")
                .foregroundStyle(.secondary)
            Text("项目：\(group.itemSummary)")
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("总费用：\(CurrencyFormatter.value(group.totalCost))")
                .foregroundStyle(.secondary)

            Button("编辑本次保养") {
                openEditLog(group.primaryLog)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    /// 保养项目维度的行视图，点击可编辑所属保养记录。
    @ViewBuilder
    private func itemRow(_ row: MaintenanceItemRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.item)
                .font(.headline)
            Text(row.log.car.map { "\($0.brand) \($0.modelName)" } ?? "未知车辆")
                .foregroundStyle(.secondary)
            Text("保养时间：\(DateTextFormatter.shortDate(row.log.date))")
                .foregroundStyle(.secondary)
            Text("里程：\(row.log.mileage) km")
                .foregroundStyle(.secondary)

            Button("编辑本次保养") {
                openEditLog(row.log)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    /// 统一打开编辑表单。
    private func openEditLog(_ log: MaintenanceLog) {
        editingLog = log
    }
}

/// 展示模式：默认按日期，支持切换按项目。
private enum LogDisplayMode: String, CaseIterable, Identifiable {
    case byDate
    case byItem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .byDate:
            return "按日期"
        case .byItem:
            return "按项目"
        }
    }
}

/// “按日期”展示时的聚合模型。
private struct MaintenanceDateGroup: Identifiable {
    let date: Date
    let logs: [MaintenanceLog]

    var id: Date { date }

    /// 同一天保养默认仅 1 条记录；历史脏数据场景下取时间最新的一条作为主展示。
    var primaryLog: MaintenanceLog {
        logs.first!
    }

    var totalCost: Double {
        logs.reduce(0) { $0 + $1.cost }
    }

    var itemSummary: String {
        let items = logs
            .flatMap { MaintenanceItemCatalog.parse($0.title) }
            .filter { !$0.isEmpty }
        let uniqueItems = Array(Set(items)).sorted()
        return uniqueItems.isEmpty ? "未标注项目" : uniqueItems.joined(separator: "、")
    }
}

/// “按项目”展示时的中间行模型。
private struct MaintenanceItemRow: Identifiable {
    let id: String
    let item: String
    let log: MaintenanceLog
}
