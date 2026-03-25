import SwiftUI

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
                    Button(viewModel.itemFilterSummary(selectedIDs: filters.wrappedValue.selectedItemIDs)) {
                        viewModel.presentSelectionSheet(mode: mode, kind: .item)
                    }
                    .buttonStyle(.plain)
                }

                if mode == .byDate {
                    LabeledContent("车辆") {
                        Button(viewModel.carFilterSummary(selectedIDs: filters.wrappedValue.selectedCarIDs)) {
                            viewModel.presentSelectionSheet(mode: mode, kind: .car)
                        }
                        .buttonStyle(.plain)
                    }

                    LabeledContent("年份") {
                        Menu {
                            Button("全部年份") {
                                filters.wrappedValue.selectedYear = nil
                            }
                            ForEach(viewModel.cycleYearOptions(cars: cars, serviceRecords: serviceRecords), id: \.self) { year in
                                Button("\(year)年") {
                                    filters.wrappedValue.selectedYear = year
                                }
                            }
                        } label: {
                            Text(viewModel.yearFilterSummary(selectedYear: filters.wrappedValue.selectedYear))
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
                Text(viewModel.filterSummary(filters: filters.wrappedValue, mode: mode))
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
    }
}
