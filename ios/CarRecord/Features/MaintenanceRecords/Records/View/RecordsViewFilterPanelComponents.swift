import SwiftUI
import SwiftData

extension RecordsView {
    @ViewBuilder
    func filterPanel(
        filters: Binding<LogFilterState>,
        mode: LogDisplayMode,
        isExpanded: Binding<Bool>
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    Button("重置") {
                        filters.wrappedValue = LogFilterState()
                    }
                    .font(.subheadline)
                }

                LabeledContent("保养项目") {
                    Button(itemFilterSummary(selectedIDs: filters.wrappedValue.selectedItemIDs)) {
                        presentSelectionSheet(mode: mode, kind: .item)
                    }
                    .buttonStyle(.plain)
                }

                if mode == .byDate {
                    LabeledContent("车辆") {
                        Button(carFilterSummary(selectedIDs: filters.wrappedValue.selectedCarIDs)) {
                            presentSelectionSheet(mode: mode, kind: .car)
                        }
                        .buttonStyle(.plain)
                    }

                    LabeledContent("年份") {
                        Menu {
                            Button("全部年份") {
                                filters.wrappedValue.selectedYear = nil
                            }
                            ForEach(cycleYearOptions, id: \.self) { year in
                                Button("\(year)年") {
                                    filters.wrappedValue.selectedYear = year
                                }
                            }
                        } label: {
                            Text(yearFilterSummary(selectedYear: filters.wrappedValue.selectedYear))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("筛选条件")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(filterSummary(filters: filters.wrappedValue, mode: mode))
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }
    var cycleYearOptions: [Int] {
        let years = scopedMaintenanceRecords.map { Calendar.current.component(.year, from: $0.date) }
        return Array(Set(years)).sorted(by: >)
    }

    /// 年份筛选摘要：空值表示不过滤年份。
    func yearFilterSummary(selectedYear: Int?) -> String {
        guard let selectedYear else { return "全部年份" }
        return "\(selectedYear)年"
    }
    func carFilterSummary(selectedIDs: Set<UUID>) -> String {
        if selectedIDs.isEmpty { return "全部车辆" }
        return "已选\(selectedIDs.count)辆"
    }

    /// 项目筛选摘要：用于筛选菜单标签展示。
    func itemFilterSummary(selectedIDs: Set<UUID>) -> String {
        if selectedIDs.isEmpty { return "全部项目" }
        return "已选\(selectedIDs.count)项"
    }

    /// 筛选摘要：用于折叠态快速提示当前已生效条件数量。
    func filterSummary(filters: LogFilterState, mode: LogDisplayMode) -> String {
        var activeCount = 0
        if filters.selectedItemIDs.isEmpty == false {
            activeCount += 1
        }
        if mode == .byDate {
            if filters.selectedCarIDs.isEmpty == false {
                activeCount += 1
            }
            if filters.selectedYear != nil {
                activeCount += 1
            }
        }
        if activeCount == 0 {
            return "未设置"
        }
        return "已设置\(activeCount)项"
    }

}
