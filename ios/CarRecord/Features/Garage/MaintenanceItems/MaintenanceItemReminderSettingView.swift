import SwiftUI
import SwiftData
import Foundation

/// 保养项目提醒设置页：每个项目都可单独配置里程/时间提醒，且至少保留一种。
struct MaintenanceItemReminderSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var serviceItemOptions: [MaintenanceItemOption]

    let option: MaintenanceItemOption

    @State private var itemName: String
    @State private var remindByMileage: Bool
    @State private var mileageInterval: Int
    @State private var remindByTime: Bool
    @State private var yearInterval: Double
    @State private var warningStartPercent: Int
    @State private var dangerStartPercent: Int
    @State private var isValidationAlertPresented = false
    @State private var validationMessage = "请至少保留一种提醒方式。"
    @State private var operationErrorMessage = ""
    @State private var isOperationErrorAlertPresented = false

    init(option: MaintenanceItemOption) {
        self.option = option
        _itemName = State(initialValue: option.name)
        _remindByMileage = State(initialValue: option.remindByMileage)
        _mileageInterval = State(initialValue: max(1_000, option.mileageInterval == 0 ? 5_000 : option.mileageInterval))
        _remindByTime = State(initialValue: option.remindByTime)
        let normalizedMonths = max(1, option.monthInterval)
        _yearInterval = State(initialValue: max(0.5, Double(normalizedMonths) / 12.0))
        let thresholds = MaintenanceItemConfig.normalizedProgressThresholds(
            warning: option.warningStartPercent,
            danger: option.dangerStartPercent
        )
        _warningStartPercent = State(initialValue: thresholds.warning)
        _dangerStartPercent = State(initialValue: thresholds.danger)
    }

    var body: some View {
        Form {
            Section("项目名称") {
                TextField("项目名称", text: $itemName)
            }

            Section("提醒方式") {
                Toggle("按里程提醒", isOn: $remindByMileage)
                if remindByMileage {
                    Stepper(value: $mileageInterval, in: 1_000...100_000, step: 500) {
                        Text("里程间隔：\(mileageInterval) km")
                    }
                }

                Toggle("按时间提醒", isOn: $remindByTime)
                if remindByTime {
                    Stepper(value: $yearInterval, in: 0.5...10, step: 0.5) {
                        Text("时间间隔：\(yearIntervalText)年")
                    }
                }
            }

            Section("进度颜色阈值（%）") {
                Stepper(value: $warningStartPercent, in: 50...300, step: 5) {
                    Text("黄色阈值：\(warningStartPercent)%")
                }

                Stepper(value: $dangerStartPercent, in: 55...400, step: 5) {
                    Text("红色阈值：\(dangerStartPercent)%")
                }

                Text("默认值：100%~125% 显示黄色，超过 125% 显示红色。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("至少开启一种提醒方式。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(option.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveReminderSetting()
                }
            }
        }
        .alert("提醒设置不完整", isPresented: $isValidationAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .alert("保存失败", isPresented: $isOperationErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
        .onChange(of: warningStartPercent) { _, newValue in
            if dangerStartPercent <= newValue {
                dangerStartPercent = newValue + 5
            }
        }
    }

    /// 至少开启一种提醒方式，并且对应间隔值有效。
    private var canSave: Bool {
        (remindByMileage && mileageInterval > 0) || (remindByTime && yearInterval > 0)
    }

    /// 项目名称校验：非空，且不与其他项目重名。
    private var isNameValid: Bool {
        let normalized = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }

        return serviceItemOptions
            .filter { $0.id != option.id }
            .contains(where: { $0.name == normalized }) == false
    }

    /// 统一“年”文案格式：整数不带小数，半年度显示 0.5。
    private var yearIntervalText: String {
        if yearInterval.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(yearInterval))
        }
        return String(format: "%.1f", yearInterval)
    }

    /// 保存提醒配置并回写到本地数据库。
    private func saveReminderSetting() {
        let normalizedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            validationMessage = "项目名称不能为空。"
            isValidationAlertPresented = true
            return
        }

        guard isNameValid else {
            validationMessage = "项目名称已存在，请换一个名称。"
            isValidationAlertPresented = true
            return
        }

        guard canSave else {
            validationMessage = "请至少保留一种提醒方式。"
            isValidationAlertPresented = true
            return
        }

        let thresholds = MaintenanceItemConfig.normalizedProgressThresholds(
            warning: warningStartPercent,
            danger: dangerStartPercent
        )
        guard thresholds.danger > thresholds.warning else {
            validationMessage = "红色阈值必须大于黄色阈值。"
            isValidationAlertPresented = true
            return
        }

        option.name = normalizedName

        option.remindByMileage = remindByMileage
        option.mileageInterval = remindByMileage ? max(1, mileageInterval) : 0
        option.remindByTime = remindByTime
        let months = max(1, Int((yearInterval * 12).rounded()))
        option.monthInterval = remindByTime ? months : 0
        option.warningStartPercent = thresholds.warning
        option.dangerStartPercent = thresholds.danger

        if let message = modelContext.saveOrLog("保存保养项目提醒设置") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
            return
        }
        dismiss()
    }
}
