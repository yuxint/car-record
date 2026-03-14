import SwiftUI
import SwiftData

/// “我的”页：集中放置车辆管理、项目管理入口和数据重置入口。
struct MyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) private var cars: [Car]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]

    @State private var activeCarForm: CarFormTarget?
    @State private var isResetAlertPresented = false

    var body: some View {
        List {
            Section("车辆管理") {
                if cars.isEmpty {
                    Text("还没有车辆，点击下方“添加车辆”开始记录。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cars) { car in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(car.brand) \(car.modelName)")
                                .font(.headline)
                            Text("上路日期：\(DateTextFormatter.shortDate(car.purchaseDate))")
                                .foregroundStyle(.secondary)
                            Text("车龄：\(CarAgeFormatter.yearsText(from: car.purchaseDate)) 年")
                                .foregroundStyle(.secondary)
                            Text("里程：\(car.mileage) km")
                                .foregroundStyle(.secondary)

                            Button("编辑车辆") {
                                openEditCarForm(car)
                            }
                            .font(.subheadline)
                            .buttonStyle(.borderless)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: deleteCars)
                }

                Button {
                    openAddCarForm()
                } label: {
                    Label("添加车辆", systemImage: "plus")
                }
            }

            Section("保养项目") {
                NavigationLink {
                    MaintenanceItemManagerView()
                } label: {
                    HStack {
                        Text("保养项目管理")
                        Spacer()
                        Text("\(maintenanceItemOptions.count)项")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }

            Section("数据管理") {
                Button(role: .destructive) {
                    isResetAlertPresented = true
                } label: {
                    Label("重置全部数据", systemImage: "trash")
                }
            }
        }
        .navigationTitle("我的")
        .onAppear {
            MaintenanceItemCatalog.ensureDefaults(in: modelContext)
        }
        .sheet(item: $activeCarForm) { target in
            switch target {
            case .add:
                AddCarView()
            case .edit(let car):
                AddCarView(editingCar: car)
            }
        }
        .alert("确认重置数据？", isPresented: $isResetAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("确认重置", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("将清空车辆、保养记录和自定义保养项目，且无法恢复。")
        }
    }

    /// 删除后立即保存，确保本地数据库状态与界面一致。
    private func deleteCars(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cars[index])
        }
        try? modelContext.save()
    }

    /// 打开新增车辆表单。
    private func openAddCarForm() {
        activeCarForm = .add
    }

    /// 打开编辑车辆表单。
    private func openEditCarForm(_ car: Car) {
        activeCarForm = .edit(car)
    }

    /// 清空所有业务数据，重置为初始状态。
    private func resetAllData() {
        do {
            let allCars = try modelContext.fetch(FetchDescriptor<Car>())
            for car in allCars {
                modelContext.delete(car)
            }

            /// 兜底删除孤立保养记录，避免历史异常数据残留。
            let allMaintenanceLogs = try modelContext.fetch(FetchDescriptor<MaintenanceLog>())
            for log in allMaintenanceLogs {
                modelContext.delete(log)
            }

            let allMaintenanceItems = try modelContext.fetch(FetchDescriptor<MaintenanceItemOption>())
            for item in allMaintenanceItems {
                modelContext.delete(item)
            }

            try modelContext.save()
            MaintenanceItemCatalog.ensureDefaults(in: modelContext)
        } catch {
            print("重置数据失败：\(error)")
        }
    }
}

/// “新增/编辑车辆”弹窗路由：避免首次打开编辑页时状态不同步。
private enum CarFormTarget: Identifiable {
    case add
    case edit(Car)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let car):
            return "edit-\(car.id.uuidString)"
        }
    }
}

/// 保养项目管理页：集中处理自定义新增、删除和关联记录清理引导。
private struct MaintenanceItemManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceLog.date, order: .reverse) private var maintenanceLogs: [MaintenanceLog]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]

    @State private var customItemName = ""
    @State private var deleteBlockedItemName = ""
    @State private var deleteBlockedLogCount = 0
    @State private var isDeleteBlockedAlertPresented = false
    @State private var isRestoreDefaultsAlertPresented = false
    @State private var logHandlingTarget: MaintenanceItemHandleTarget?

    var body: some View {
        List {
            Section("新增自定义项目") {
                HStack(spacing: 8) {
                    TextField("新增自定义保养项目", text: $customItemName)
                    Button("添加") {
                        addCustomMaintenanceItem()
                    }
                    .disabled(!canAddCustomMaintenanceItem)
                }
            }

            Section("项目列表") {
                ForEach(sortedMaintenanceItemOptions) { option in
                    NavigationLink {
                        MaintenanceItemReminderSettingView(option: option)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(option.name)
                                    .lineLimit(1)

                                if option.isDefault {
                                    Text("默认")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text("提醒规则：\(MaintenanceItemCatalog.reminderSummary(for: option))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }

                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if option.isDefault == false {
                            Button(role: .destructive) {
                                attemptDeleteCustomMaintenanceItem(option)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("默认配置") {
                Button(role: .destructive) {
                    isRestoreDefaultsAlertPresented = true
                } label: {
                    Text("恢复默认值")
                }
            }
        }
        .navigationTitle("保养项目管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            MaintenanceItemCatalog.ensureDefaults(in: modelContext)
        }
        .sheet(item: $logHandlingTarget) { target in
            ItemRelatedLogsView(itemName: target.id)
        }
        .alert("无法删除该保养项目", isPresented: $isDeleteBlockedAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("去处理记录") {
                logHandlingTarget = MaintenanceItemHandleTarget(id: deleteBlockedItemName)
            }
        } message: {
            Text("“\(deleteBlockedItemName)”已被\(deleteBlockedLogCount)条保养记录使用，请先修改或删除对应记录。")
        }
        .alert("恢复默认值？", isPresented: $isRestoreDefaultsAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                restoreDefaultMaintenanceItems()
            }
        } message: {
            Text("将把默认保养项目名称和提醒规则恢复为初始值，自定义项目保留不变。")
        }
    }

    /// 默认项目优先，其次按创建时间展示自定义项目。
    private var sortedMaintenanceItemOptions: [MaintenanceItemOption] {
        maintenanceItemOptions.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault && !rhs.isDefault
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// 自定义项目新增校验：非空且不与现有项目重名。
    private var canAddCustomMaintenanceItem: Bool {
        let normalized = customItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        return !maintenanceItemOptions.map(\.name).contains(normalized)
    }

    /// 添加自定义保养项目并持久化。
    private func addCustomMaintenanceItem() {
        let normalized = customItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard !maintenanceItemOptions.map(\.name).contains(normalized) else { return }

        modelContext.insert(
            MaintenanceItemOption(
                name: normalized,
                isDefault: false,
                remindByMileage: true,
                mileageInterval: 5000,
                remindByTime: false,
                monthInterval: 0
            )
        )
        try? modelContext.save()
        customItemName = ""
    }

    /// 尝试删除自定义项目；若存在关联记录，则引导用户先处理记录。
    private func attemptDeleteCustomMaintenanceItem(_ option: MaintenanceItemOption) {
        guard option.isDefault == false else { return }

        let relatedLogs = maintenanceLogs.filter {
            MaintenanceItemCatalog.parse($0.title).contains(option.name)
        }

        if relatedLogs.isEmpty {
            modelContext.delete(option)
            try? modelContext.save()
            return
        }

        deleteBlockedItemName = option.name
        deleteBlockedLogCount = relatedLogs.count
        isDeleteBlockedAlertPresented = true
    }

    /// 恢复默认项目名称与提醒规则，并同步更新历史保养记录中的项目名称。
    private func restoreDefaultMaintenanceItems() {
        let defaultOptions = maintenanceItemOptions
            .filter(\.isDefault)
            .sorted { $0.createdAt < $1.createdAt }

        let defaultNames = MaintenanceItemCatalog.allItems
        let count = min(defaultOptions.count, defaultNames.count)

        var renameMap: [String: String] = [:]
        for index in 0..<count {
            let option = defaultOptions[index]
            let targetName = defaultNames[index]

            if let conflict = maintenanceItemOptions.first(where: { $0.name == targetName && $0.id != option.id }) {
                modelContext.delete(conflict)
            }

            if option.name != targetName {
                renameMap[option.name] = targetName
                option.name = targetName
            }

            let rule = MaintenanceItemCatalog.defaultRule(for: targetName)
            option.remindByMileage = rule.mileage != nil
            option.mileageInterval = rule.mileage ?? 0
            option.remindByTime = rule.months != nil
            option.monthInterval = rule.months ?? 0
        }

        for log in maintenanceLogs {
            let items = MaintenanceItemCatalog.parse(log.title)
            let normalized = items.map { renameMap[$0] ?? $0 }
            if normalized != items {
                log.title = MaintenanceItemCatalog.join(normalized)
            }
        }

        try? modelContext.save()
    }
}

/// 保养项目提醒设置页：每个项目都可单独配置里程/时间提醒，且至少保留一种。
private struct MaintenanceItemReminderSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceLog.date, order: .reverse) private var maintenanceLogs: [MaintenanceLog]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]

    let option: MaintenanceItemOption

    @State private var itemName: String
    @State private var remindByMileage: Bool
    @State private var mileageInterval: Int
    @State private var remindByTime: Bool
    @State private var yearInterval: Double
    @State private var isValidationAlertPresented = false
    @State private var validationMessage = "请至少保留一种提醒方式。"

    init(option: MaintenanceItemOption) {
        self.option = option
        _itemName = State(initialValue: option.name)
        _remindByMileage = State(initialValue: option.remindByMileage)
        _mileageInterval = State(initialValue: max(1_000, option.mileageInterval == 0 ? 5_000 : option.mileageInterval))
        _remindByTime = State(initialValue: option.remindByTime)
        let fallbackMonths = option.monthInterval == 0 ? 12 : option.monthInterval
        _yearInterval = State(initialValue: max(0.5, Double(fallbackMonths) / 12.0))
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
    }

    /// 至少开启一种提醒方式，并且对应间隔值有效。
    private var canSave: Bool {
        (remindByMileage && mileageInterval > 0) || (remindByTime && yearInterval > 0)
    }

    /// 项目名称校验：非空，且不与其他项目重名。
    private var isNameValid: Bool {
        let normalized = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }

        return maintenanceItemOptions
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

        if option.name != normalizedName {
            for log in maintenanceLogs {
                let items = MaintenanceItemCatalog.parse(log.title)
                let renamed = items.map { $0 == option.name ? normalizedName : $0 }
                if renamed != items {
                    log.title = MaintenanceItemCatalog.join(renamed)
                }
            }
            option.name = normalizedName
        }

        option.remindByMileage = remindByMileage
        option.mileageInterval = remindByMileage ? max(1, mileageInterval) : 0
        option.remindByTime = remindByTime
        let months = max(1, Int((yearInterval * 12).rounded()))
        option.monthInterval = remindByTime ? months : 0

        try? modelContext.save()
        dismiss()
    }
}

/// 标识“去处理记录”时需要打开的项目。
private struct MaintenanceItemHandleTarget: Identifiable {
    let id: String
}

/// 某个保养项目的关联记录处理页：支持编辑或删除。
private struct ItemRelatedLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceLog.date, order: .reverse) private var maintenanceLogs: [MaintenanceLog]

    let itemName: String

    @State private var editingLog: MaintenanceLog?

    private var relatedLogs: [MaintenanceLog] {
        maintenanceLogs.filter {
            MaintenanceItemCatalog.parse($0.title).contains(itemName)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if relatedLogs.isEmpty {
                    Text("当前项目已无关联记录，可以返回继续删除该项目。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(relatedLogs) { log in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(log.car.map { "\($0.brand) \($0.modelName)" } ?? "未知车辆")
                                .font(.headline)
                            Text("保养时间：\(DateTextFormatter.shortDate(log.date))")
                                .foregroundStyle(.secondary)
                            Text("里程：\(log.mileage) km")
                                .foregroundStyle(.secondary)
                            Text("总费用：\(CurrencyFormatter.value(log.cost))")
                                .foregroundStyle(.secondary)

                            Button("编辑该记录") {
                                editingLog = log
                            }
                            .buttonStyle(.borderless)
                            .font(.subheadline)
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteRelatedLogs)
                }
            }
            .navigationTitle("处理“\(itemName)”记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $editingLog) { log in
            AddMaintenanceLogView(editingLog: log)
        }
    }

    /// 删除关联保养记录。
    private func deleteRelatedLogs(at offsets: IndexSet) {
        let currentRelatedLogs = relatedLogs
        for index in offsets {
            modelContext.delete(currentRelatedLogs[index])
        }
        try? modelContext.save()
    }
}
