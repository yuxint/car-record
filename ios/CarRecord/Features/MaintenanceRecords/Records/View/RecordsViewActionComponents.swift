import SwiftUI

extension RecordsView {
    @ViewBuilder
    func dateGroupRow(_ group: MaintenanceDateGroup) -> some View {
        let rawCarNames = group.records.compactMap(\.car).map(CarDisplayFormatter.name)
        let carNames = Array(Set(rawCarNames))
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
        let note = group.records.first?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let minMileage = group.records.map(\.mileage).min()
        let maxMileage = group.records.map(\.mileage).max()

        VStack(alignment: .leading, spacing: 6) {
            Text(AppDateContext.formatShortDate(group.date))
                .font(.headline)

            if group.records.count == 1, let singleRecord = group.records.first {
                Text("里程：\(singleRecord.mileage) km")
                    .foregroundStyle(.secondary)
            } else {
                Text("涉及车辆：\(carNames.joined(separator: "、"))")
                    .foregroundStyle(.secondary)
                if let minMileage, let maxMileage {
                    if minMileage == maxMileage {
                        Text("里程：\(minMileage) km")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("里程：\(maxMileage) km")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("项目：\(group.itemSummary)")
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("总费用：\(CurrencyFormatter.value(group.totalCost))")
                .foregroundStyle(.secondary)
            if note.isEmpty == false {
                Text("备注：\(note)")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if group.records.count == 1, let singleRecord = group.records.first {
                Button("编辑本次保养") {
                    viewModel.openEditRecord(singleRecord)
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    func itemRow(_ row: MaintenanceItemRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.itemName)
                .font(.headline)
            Text("保养时间：\(AppDateContext.formatShortDate(row.record.date))")
                .foregroundStyle(.secondary)
            Text("里程：\(row.record.mileage) km")
                .foregroundStyle(.secondary)

            Button("编辑本次保养") {
                viewModel.openEditRecord(row.record, lockedItemID: row.itemID)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}
