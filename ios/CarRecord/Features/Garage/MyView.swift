import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// “我的”页：集中放置车辆管理、项目管理入口和数据重置入口。
struct MyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) private var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) private var appliedCarIDRaw = ""

    @State private var activeCarForm: CarFormTarget?
    @State private var isResetAlertPresented = false
    @State private var isImportingMaintenanceData = false
    @State private var isExportingMaintenanceData = false
    @State private var exportDocument = MaintenanceDataTransferDocument(data: Data())
    @State private var exportFilename = "car-record-maintenance"
    @State private var transferResultMessage = ""
    @State private var isTransferResultAlertPresented = false
    @State private var isRestoreConfirmAlertPresented = false
    @State private var operationErrorMessage = ""
    @State private var isOperationErrorAlertPresented = false
    @State private var isManualNowEnabled = AppDateContext.isManualNowEnabled()
    @State private var manualNowDate = AppDateContext.manualNowDate()
    @State private var draftManualNowDate = AppDateContext.manualNowDate()
    @State private var isManualNowPickerPresented = false

    var body: some View {
        List {
            Section("车辆管理") {
                if cars.isEmpty {
                    Text("还没有车辆，点击下方“添加车辆”开始记录。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cars) { car in
                        let isApplied = isAppliedCar(car)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(CarDisplayFormatter.name(car))
                                .font(.headline)

                            Text("上路日期：\(AppDateContext.formatShortDate(car.purchaseDate))")
                                .foregroundStyle(.secondary)
                            Text("车龄：\(CarAgeFormatter.yearsText(from: car.purchaseDate, now: AppDateContext.now())) 年")
                                .foregroundStyle(.secondary)
                            Text("里程：\(car.mileage) km")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            (isApplied ? Color.blue.opacity(0.08) : Color(.secondarySystemBackground)),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isApplied ? Color.blue.opacity(0.35) : Color(.separator),
                                    lineWidth: 1
                                )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteCar(car)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                applyCar(car)
                            } label: {
                                Label(isApplied ? "已应用" : "应用", systemImage: "checkmark.circle")
                            }
                            .tint(.blue)
                            .disabled(isApplied)

                            Button {
                                openEditCarForm(car)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Button {
                    openAddCarForm()
                } label: {
                    Label("添加车辆", systemImage: "plus")
                }
            }

            Section("数据管理") {
                Button {
                    startBackupData()
                } label: {
                    Label("备份数据", systemImage: "square.and.arrow.up")
                }

                Button {
                    if hasAnyBusinessData {
                        isRestoreConfirmAlertPresented = true
                    } else {
                        isImportingMaintenanceData = true
                    }
                } label: {
                    Label("恢复数据", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    isResetAlertPresented = true
                } label: {
                    Label("重置全部数据", systemImage: "trash")
                }

                Text("备份按车型保存保养项目配置与车辆记录。恢复会使用备份内容覆盖当前数据，且在有数据时先二次确认再清空。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("时间临时设置") {
                Toggle("不取系统时间，改为手动日期", isOn: $isManualNowEnabled)
                    .onChange(of: isManualNowEnabled) { _, newValue in
                        AppDateContext.setManualNowEnabled(newValue)
                    }

                if isManualNowEnabled {
                    Button {
                        draftManualNowDate = manualNowDate
                        isManualNowPickerPresented = true
                    } label: {
                        HStack {
                            Text("手动日期")
                            Spacer()
                            Text(AppDateContext.formatShortDate(manualNowDate))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Text("仅影响本地“当前日期”计算（如车龄、提醒进度、今日里程同步），不会修改历史记录日期。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                HStack {
                    Text("版本号")
                    Spacer()
                    Text(appVersionText)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("我的")
        .sheet(item: $activeCarForm) { target in
            switch target {
            case .add:
                AddCarView()
            case .edit(let car):
                AddCarView(editingCar: car)
            }
        }
        .sheet(isPresented: $isManualNowPickerPresented) {
            DayDatePickerSheetView(
                title: "选择日期",
                label: "手动日期",
                draftDate: $draftManualNowDate,
                currentDate: manualNowDate,
                onApply: { newValue in
                    manualNowDate = newValue
                    AppDateContext.setManualNowDate(newValue)
                    isManualNowPickerPresented = false
                },
                onCancel: { isManualNowPickerPresented = false }
            )
        }
        .fileExporter(
            isPresented: $isExportingMaintenanceData,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success(let url):
                presentTransferResult("备份成功：\(url.lastPathComponent)")
            case .failure(let error):
                presentTransferResult("备份失败：\(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $isImportingMaintenanceData,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    presentTransferResult("恢复失败：未选择文件。")
                    return
                }
                importMaintenanceData(from: url)
            case .failure(let error):
                presentTransferResult("恢复失败：\(error.localizedDescription)")
            }
        }
        .alert("确认重置数据？", isPresented: $isResetAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("确认重置", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("将清空车辆、保养记录和全部保养项目，且无法恢复。")
        }
        .alert("确认恢复数据？", isPresented: $isRestoreConfirmAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("确认恢复", role: .destructive) {
                isImportingMaintenanceData = true
            }
        } message: {
            Text("恢复会先清空当前全部数据，再导入备份文件。")
        }
        .alert("备份恢复结果", isPresented: $isTransferResultAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(transferResultMessage)
        }
        .alert("操作失败", isPresented: $isOperationErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
        .onAppear {
            syncAppliedCarSelection()
            isManualNowEnabled = AppDateContext.isManualNowEnabled()
            manualNowDate = AppDateContext.manualNowDate()
            draftManualNowDate = manualNowDate
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            syncAppliedCarSelection()
        }
    }

    /// 删除后立即保存，确保本地数据库状态与界面一致。
    private func deleteCars(at offsets: IndexSet) {
        let deletedIDs = Set(offsets.compactMap { cars.indices.contains($0) ? cars[$0].id : nil })
        for index in offsets {
            modelContext.delete(cars[index])
        }
        if let message = modelContext.saveOrLog("删除车辆") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
            return
        }
        if let appliedCarID = AppliedCarContext.decodeCarID(from: appliedCarIDRaw),
           deletedIDs.contains(appliedCarID) {
            syncAppliedCarSelection()
        }
    }

    /// 打开新增车辆表单。
    private func openAddCarForm() {
        activeCarForm = .add
    }

    /// 打开编辑车辆表单。
    private func openEditCarForm(_ car: Car) {
        activeCarForm = .edit(car)
    }

    /// 左滑删除单车：与批量删除逻辑保持一致的保存与报错处理。
    private func deleteCar(_ car: Car) {
        guard let index = cars.firstIndex(where: { $0.id == car.id }) else { return }
        deleteCars(at: IndexSet(integer: index))
    }

    /// 应用车型：概览页与记录页会按该车型隔离读取/写入数据。
    private func applyCar(_ car: Car) {
        appliedCarIDRaw = AppliedCarContext.encodeCarID(car.id)
    }

    /// 判断车辆是否为当前已应用车型。
    private func isAppliedCar(_ car: Car) -> Bool {
        AppliedCarContext.decodeCarID(from: appliedCarIDRaw) == car.id
    }

    /// 清空所有业务数据，重置为初始状态。
    private func resetAllData() {
        do {
            try clearAllBusinessData()
        } catch {
            operationErrorMessage = "重置数据失败，请稍后重试。"
            isOperationErrorAlertPresented = true
        }
    }

    /// 导出当前全部车辆及其关联保养数据，作为本地备份文件。
    private func startBackupData() {
        var logsByCarID: [UUID: [MaintenanceRecord]] = [:]
        for log in maintenanceRecords {
            guard let carID = log.car?.id else { continue }
            logsByCarID[carID, default: []].append(log)
        }
        let vehicles = cars.map { car in
            let relatedLogs = (logsByCarID[car.id] ?? [])
                .sorted { lhs, rhs in
                    if lhs.date != rhs.date {
                        return lhs.date < rhs.date
                    }
                    return lhs.mileage < rhs.mileage
                }

            let carPayload = MaintenanceDataTransferCarPayload(
                id: car.id,
                brand: car.brand,
                modelName: car.modelName,
                mileage: car.mileage,
                purchaseDate: exportDateString(car.purchaseDate)
            )

            let logPayloads = relatedLogs.map { log in
                MaintenanceDataTransferLogPayload(
                    id: log.id,
                    date: exportDateString(log.date),
                    itemNames: MaintenanceItemCatalog.itemNames(
                        from: log.itemIDsRaw,
                        options: maintenanceItemOptions
                    ),
                    cost: log.cost,
                    mileage: log.mileage,
                    note: log.note
                )
            }

            return MaintenanceDataTransferVehiclePayload(
                car: carPayload,
                maintenanceLogs: logPayloads
            )
        }

        var modelKeys = Set<String>()
        let modelProfiles = cars.compactMap { car -> MaintenanceDataTransferModelProfilePayload? in
            let key = modelProfileKey(brand: car.brand, modelName: car.modelName)
            if modelKeys.contains(key) {
                return nil
            }
            modelKeys.insert(key)
            return MaintenanceDataTransferModelProfilePayload(
                brand: car.brand,
                modelName: car.modelName,
                maintenanceItems: maintenanceItemOptions.map { option in
                    MaintenanceDataTransferItemPayload(
                        id: option.id,
                        name: option.name,
                        isDefault: option.isDefault,
                        catalogKey: option.catalogKey,
                        remindByMileage: option.remindByMileage,
                        mileageInterval: option.mileageInterval,
                        remindByTime: option.remindByTime,
                        monthInterval: option.monthInterval,
                        warningStartPercent: option.warningStartPercent,
                        dangerStartPercent: option.dangerStartPercent,
                        createdAt: option.createdAt.timeIntervalSince1970
                    )
                }
            )
        }

        let payload = MaintenanceDataTransferPayload(
            modelProfiles: modelProfiles,
            vehicles: vehicles
        )
        guard let encodedData = try? MaintenanceDataTransferCodec.encoder.encode(payload) else {
            presentTransferResult("备份失败：数据编码失败。")
            return
        }

        exportDocument = MaintenanceDataTransferDocument(data: encodedData)
        exportFilename = "car-record-backup-\(timestampForFilename(Date()))"
        isExportingMaintenanceData = true
    }

    /// 从 JSON 文件恢复车辆与保养数据：恢复前会先清空本地业务数据。
    private func importMaintenanceData(from url: URL) {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try MaintenanceDataTransferCodec.decoder.decode(
                MaintenanceDataTransferPayload.self,
                from: data
            )
            try clearAllBusinessData()
            let summary = try applyImportedPayload(payload)
            presentTransferResult(summary.message)
        } catch {
            modelContext.rollback()
            presentTransferResult("恢复失败：请确认备份文件完整且结构正确。")
        }
    }

    /// 应用恢复数据并返回统计结果：会在空库中重建保养项目、车辆与记录。
    private func applyImportedPayload(_ payload: MaintenanceDataTransferPayload) throws -> MaintenanceDataTransferImportSummary {
        var optionsByName: [String: MaintenanceItemOption] = [:]
        var summary = MaintenanceDataTransferImportSummary()
        var profileByKey: [String: MaintenanceDataTransferModelProfilePayload] = [:]
        for profile in payload.modelProfiles {
            let key = modelProfileKey(brand: profile.brand, modelName: profile.modelName)
            if profileByKey[key] != nil {
                throw NSError(
                    domain: "MaintenanceDataTransfer",
                    code: 1010,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(profile.brand) \(profile.modelName)”重复。"]
                )
            }
            profileByKey[key] = profile
        }

        if profileByKey.isEmpty, payload.vehicles.isEmpty == false {
            throw NSError(
                domain: "MaintenanceDataTransfer",
                code: 1011,
                userInfo: [NSLocalizedDescriptionKey: "恢复失败：备份缺少车型保养项目配置。"]
            )
        }

        for profile in payload.modelProfiles {
            var profileItemNames = Set<String>()
            for item in profile.maintenanceItems {
                let normalizedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard normalizedName.isEmpty == false else {
                    throw NSError(
                        domain: "MaintenanceDataTransfer",
                        code: 1008,
                        userInfo: [NSLocalizedDescriptionKey: "恢复失败：保养项目名称不能为空。"]
                    )
                }
                if profileItemNames.contains(normalizedName) {
                    throw NSError(
                        domain: "MaintenanceDataTransfer",
                        code: 1009,
                        userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(profile.brand) \(profile.modelName)”存在重复项目“\(normalizedName)”。"]
                    )
                }
                profileItemNames.insert(normalizedName)

                if let existing = optionsByName[normalizedName] {
                    if existing.remindByMileage != item.remindByMileage ||
                        existing.mileageInterval != item.mileageInterval ||
                        existing.remindByTime != item.remindByTime ||
                        existing.monthInterval != item.monthInterval ||
                        existing.warningStartPercent != item.warningStartPercent ||
                        existing.dangerStartPercent != item.dangerStartPercent {
                        throw NSError(
                            domain: "MaintenanceDataTransfer",
                            code: 1012,
                            userInfo: [NSLocalizedDescriptionKey: "恢复失败：项目“\(normalizedName)”在不同车型配置冲突。"]
                        )
                    }
                    continue
                }

                let option = MaintenanceItemOption(
                    id: item.id,
                    name: normalizedName,
                    isDefault: item.isDefault,
                    catalogKey: item.catalogKey,
                    remindByMileage: item.remindByMileage,
                    mileageInterval: item.mileageInterval,
                    remindByTime: item.remindByTime,
                    monthInterval: item.monthInterval,
                    warningStartPercent: item.warningStartPercent,
                    dangerStartPercent: item.dangerStartPercent,
                    createdAt: Date(timeIntervalSince1970: item.createdAt)
                )
                modelContext.insert(option)
                optionsByName[normalizedName] = option
                summary.insertedItems += 1
            }
        }

        var importedCarIDs = Set<UUID>()
        var importedModelKeys = Set<String>()
        var importedLogIDs = Set<UUID>()
        let dateOnlyFormatter = AppDateContext.makeDisplayFormatter("yyyy-MM-dd")
        dateOnlyFormatter.isLenient = false

        for vehicle in payload.vehicles {
            let carPayload = vehicle.car
            guard
                let parsedCarPurchaseDate = dateOnlyFormatter.date(from: carPayload.purchaseDate),
                dateOnlyFormatter.string(from: parsedCarPurchaseDate) == carPayload.purchaseDate
            else {
                throw NSError(
                    domain: "MaintenanceDataTransfer",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "车辆上路日期格式错误：\(carPayload.purchaseDate)。请使用 yyyy-MM-dd。"]
                )
            }
            if importedCarIDs.contains(carPayload.id) {
                throw NSError(
                    domain: "MaintenanceDataTransfer",
                    code: 1004,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：备份内车辆ID \(carPayload.id.uuidString) 重复。"]
                )
            }
            importedCarIDs.insert(carPayload.id)
            let profileKey = modelProfileKey(brand: carPayload.brand, modelName: carPayload.modelName)
            guard profileByKey[profileKey] != nil else {
                throw NSError(
                    domain: "MaintenanceDataTransfer",
                    code: 1013,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(carPayload.brand) \(carPayload.modelName)”缺少保养项目配置。"]
                )
            }

            /// 同车型唯一约束：恢复数据时也禁止同一品牌+车型出现多辆车。
            if importedModelKeys.contains(profileKey) {
                throw NSError(
                    domain: "MaintenanceDataTransfer",
                    code: 1014,
                    userInfo: [NSLocalizedDescriptionKey: "恢复失败：车型“\(carPayload.brand) \(carPayload.modelName)”重复，单一车型仅允许一辆车。"]
                )
            }
            importedModelKeys.insert(profileKey)
            let car = Car(
                id: carPayload.id,
                brand: carPayload.brand,
                modelName: carPayload.modelName,
                mileage: carPayload.mileage,
                purchaseDate: parsedCarPurchaseDate
            )
            modelContext.insert(car)
            summary.insertedCars += 1

            for logPayload in vehicle.maintenanceLogs {
                guard
                    let parsedLogDate = dateOnlyFormatter.date(from: logPayload.date),
                    dateOnlyFormatter.string(from: parsedLogDate) == logPayload.date
                else {
                    throw NSError(
                        domain: "MaintenanceDataTransfer",
                        code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "保养日期格式错误：\(logPayload.date)。请使用 yyyy-MM-dd。"]
                    )
                }
                if importedLogIDs.contains(logPayload.id) {
                    throw NSError(
                        domain: "MaintenanceDataTransfer",
                        code: 1005,
                        userInfo: [NSLocalizedDescriptionKey: "恢复失败：备份内保养记录ID \(logPayload.id.uuidString) 重复。"]
                    )
                }
                importedLogIDs.insert(logPayload.id)

                let itemIDs = try itemIDsForImport(
                    names: logPayload.itemNames,
                    optionsByName: optionsByName
                )
                let itemIDsRaw = MaintenanceItemCatalog.joinItemIDs(itemIDs)
                let newLog = MaintenanceRecord(
                    id: logPayload.id,
                    date: parsedLogDate,
                    itemIDsRaw: itemIDsRaw,
                    cost: logPayload.cost,
                    mileage: logPayload.mileage,
                    note: logPayload.note,
                    car: car
                )
                modelContext.insert(newLog)
                MaintenanceItemCatalog.syncCycleAndRelations(for: newLog, in: modelContext)
                summary.insertedLogs += 1
            }
        }

        try modelContext.save()
        return summary
    }

    /// 将导入项目名称映射为项目 ID；名称不存在时直接报错。
    private func itemIDsForImport(
        names: [String],
        optionsByName: [String: MaintenanceItemOption]
    ) throws -> [UUID] {
        var seen = Set<String>()
        let normalizedNames = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .filter { name in
                if seen.contains(name) {
                    return false
                }
                seen.insert(name)
                return true
            }

        guard normalizedNames.isEmpty == false else {
            throw NSError(
                domain: "MaintenanceDataTransfer",
                code: 1006,
                userInfo: [NSLocalizedDescriptionKey: "恢复失败：保养项目不能为空。"]
            )
        }

        return try normalizedNames.map { name in
            if let existing = optionsByName[name] {
                return existing.id
            }
            throw NSError(
                domain: "MaintenanceDataTransfer",
                code: 1007,
                userInfo: [NSLocalizedDescriptionKey: "恢复失败：项目“\(name)”未在车型配置中声明。"]
            )
        }
    }

    /// 当前是否存在任一业务数据：用于决定恢复是否需要二次确认。
    private var hasAnyBusinessData: Bool {
        !cars.isEmpty || !maintenanceRecords.isEmpty || !maintenanceItemOptions.isEmpty
    }

    /// 清空业务数据：用于重置和恢复前准备。
    private func clearAllBusinessData() throws {
        let allCars = try modelContext.fetch(FetchDescriptor<Car>())
        for car in allCars {
            modelContext.delete(car)
        }

        let allMaintenanceItems = try modelContext.fetch(FetchDescriptor<MaintenanceItemOption>())
        for item in allMaintenanceItems {
            modelContext.delete(item)
        }

        let allLogs = try modelContext.fetch(FetchDescriptor<MaintenanceRecord>())
        for log in allLogs {
            modelContext.delete(log)
        }

        try modelContext.save()
        appliedCarIDRaw = ""
    }

    /// 同步并修正已应用车型，保证删除/恢复后不会引用失效车辆。
    private func syncAppliedCarSelection() {
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 统一弹出备份恢复处理结果，避免各入口文案风格不一致。
    private func presentTransferResult(_ message: String) {
        transferResultMessage = message
        isTransferResultAlertPresented = true
    }

    /// 生成导出文件名时间戳，避免重复导出时文件名覆盖。
    private func timestampForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    /// 导出统一日期格式：只保留"年-月-日"，与表单输入口径保持一致。
    private func exportDateString(_ date: Date) -> String {
        AppDateContext.formatShortDate(date)
    }

    /// 车型配置键：用于备份与恢复时按“品牌+车型”匹配项目配置。
    private func modelProfileKey(brand: String, modelName: String) -> String {
        "\(brand.trimmingCharacters(in: .whitespacesAndNewlines))|\(modelName.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// 统一读取 App 包内版本号，确保与安装页使用同一构建注入值。
    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let normalized = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized
    }
}

/// 备份恢复总载荷：按“车型项目配置 + 车辆信息 -> 保养数据”固定层级组织。
private struct MaintenanceDataTransferPayload: Codable {
    var modelProfiles: [MaintenanceDataTransferModelProfilePayload]
    var vehicles: [MaintenanceDataTransferVehiclePayload]
}

/// 车型保养配置快照：按品牌+车型持久化项目配置。
private struct MaintenanceDataTransferModelProfilePayload: Codable {
    var brand: String
    var modelName: String
    var maintenanceItems: [MaintenanceDataTransferItemPayload]
}

/// 保养项目快照：恢复时先重建项目配置，再重建保养记录。
private struct MaintenanceDataTransferItemPayload: Codable {
    var id: UUID
    var name: String
    var isDefault: Bool
    var catalogKey: String?
    var remindByMileage: Bool
    var mileageInterval: Int
    var remindByTime: Bool
    var monthInterval: Int
    var warningStartPercent: Int
    var dangerStartPercent: Int
    var createdAt: TimeInterval
}

/// 单车备份恢复节点：车辆基础信息 + 该车辆下全部保养记录。
private struct MaintenanceDataTransferVehiclePayload: Codable {
    var car: MaintenanceDataTransferCarPayload
    var maintenanceLogs: [MaintenanceDataTransferLogPayload]
}

/// 车辆基础信息快照。
private struct MaintenanceDataTransferCarPayload: Codable {
    var id: UUID
    var brand: String
    var modelName: String
    var mileage: Int
    /// 仅保存日期，不保存时间与时区。
    var purchaseDate: String
}

/// 保养记录快照：项目以名称数组保存，导入时再映射到本地项目ID。
private struct MaintenanceDataTransferLogPayload: Codable {
    var id: UUID
    /// 仅保存日期，不保存时间与时区。
    var date: String
    var itemNames: [String]
    var cost: Double
    var mileage: Int
    var note: String
}

/// 导入统计：用于导入结束后统一反馈。
private struct MaintenanceDataTransferImportSummary {
    var insertedItems = 0
    var insertedCars = 0
    var insertedLogs = 0

    var message: String {
        "恢复完成：恢复项目\(insertedItems)项，恢复车辆\(insertedCars)辆，恢复保养记录\(insertedLogs)条。"
    }
}

/// 编解码器：统一 JSON 编解码配置；日期字段均使用 yyyy-MM-dd 字符串。
private enum MaintenanceDataTransferCodec {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        JSONDecoder()
    }
}

/// 文件文档封装：把备份恢复 JSON 接入 SwiftUI 的 `fileExporter/fileImporter`。
private struct MaintenanceDataTransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
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
struct MaintenanceItemManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) private var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]

    @State private var customItemName = ""
    @State private var deleteBlockedItemName = ""
    @State private var deleteBlockedItemID: UUID?
    @State private var deleteBlockedLogCount = 0
    @State private var isDeleteBlockedAlertPresented = false
    @State private var isRestoreDefaultsAlertPresented = false
    @State private var logHandlingTarget: MaintenanceItemHandleTarget?
    @State private var operationErrorMessage = ""
    @State private var isOperationErrorAlertPresented = false

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
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }
        }
        .sheet(item: $logHandlingTarget) { target in
            ItemRelatedLogsView(itemID: target.itemID, itemName: target.itemName)
        }
        .alert("无法删除该保养项目", isPresented: $isDeleteBlockedAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("去处理记录") {
                guard let deleteBlockedItemID else { return }
                logHandlingTarget = MaintenanceItemHandleTarget(
                    itemID: deleteBlockedItemID,
                    itemName: deleteBlockedItemName
                )
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
        .alert("操作失败", isPresented: $isOperationErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
    }

    /// 默认项目优先，其次按创建时间展示自定义项目。
    private var sortedMaintenanceItemOptions: [MaintenanceItemOption] {
        MaintenanceItemCatalog.naturalSortedOptions(maintenanceItemOptions)
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
                monthInterval: 0,
                warningStartPercent: MaintenanceItemCatalog.defaultWarningStartPercent,
                dangerStartPercent: MaintenanceItemCatalog.defaultDangerStartPercent
            )
        )
        if let message = modelContext.saveOrLog("新增自定义保养项目") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
            return
        }
        customItemName = ""
    }

    /// 尝试删除自定义项目；若存在关联记录，则引导用户先处理记录。
    private func attemptDeleteCustomMaintenanceItem(_ option: MaintenanceItemOption) {
        guard option.isDefault == false else { return }

        let relatedLogs = maintenanceRecords.filter {
            MaintenanceItemCatalog.contains(itemID: option.id, in: $0.itemIDsRaw)
        }

        if relatedLogs.isEmpty {
            modelContext.delete(option)
            if let message = modelContext.saveOrLog("删除自定义保养项目") {
                operationErrorMessage = message
                isOperationErrorAlertPresented = true
            }
            return
        }

        deleteBlockedItemName = option.name
        deleteBlockedItemID = option.id
        deleteBlockedLogCount = relatedLogs.count
        isDeleteBlockedAlertPresented = true
    }

    /// 恢复默认项目名称与提醒规则。
    private func restoreDefaultMaintenanceItems() {
        let primaryCar = cars.first
        let definitions = MaintenanceItemCatalog.defaultItemDefinitions(
            brand: primaryCar?.brand,
            modelName: primaryCar?.modelName
        )
        for definition in definitions {
            let existingByKey = maintenanceItemOptions.first(where: { $0.catalogKey == definition.key })

            let option: MaintenanceItemOption
            if let existingByKey {
                option = existingByKey
            } else {
                let newOption = MaintenanceItemOption(
                    name: definition.defaultName,
                    isDefault: true,
                    catalogKey: definition.key,
                    remindByMileage: definition.mileageInterval != nil,
                    mileageInterval: definition.mileageInterval ?? 0,
                    remindByTime: definition.monthInterval != nil,
                    monthInterval: definition.monthInterval ?? 0,
                    warningStartPercent: MaintenanceItemCatalog.defaultWarningStartPercent,
                    dangerStartPercent: MaintenanceItemCatalog.defaultDangerStartPercent
                )
                modelContext.insert(newOption)
                continue
            }

            if let conflict = maintenanceItemOptions.first(where: { $0.name == definition.defaultName && $0.id != option.id }) {
                modelContext.delete(conflict)
            }

            option.isDefault = true
            option.catalogKey = definition.key
            option.name = definition.defaultName
            option.remindByMileage = definition.mileageInterval != nil
            option.mileageInterval = definition.mileageInterval ?? 0
            option.remindByTime = definition.monthInterval != nil
            option.monthInterval = definition.monthInterval ?? 0
            option.warningStartPercent = MaintenanceItemCatalog.defaultWarningStartPercent
            option.dangerStartPercent = MaintenanceItemCatalog.defaultDangerStartPercent
        }

        if let message = modelContext.saveOrLog("恢复默认保养项目") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
        }
    }
}

/// 保养项目提醒设置页：每个项目都可单独配置里程/时间提醒，且至少保留一种。
private struct MaintenanceItemReminderSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]

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
        let thresholds = MaintenanceItemCatalog.normalizedProgressThresholds(
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

        let thresholds = MaintenanceItemCatalog.normalizedProgressThresholds(
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

/// 标识“去处理记录”时需要打开的项目。
private struct MaintenanceItemHandleTarget: Identifiable {
    let itemID: UUID
    let itemName: String

    var id: String { itemID.uuidString }
}

/// 某个保养项目的关联记录处理页：支持编辑或删除。
private struct ItemRelatedLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]

    let itemID: UUID
    let itemName: String

    @State private var editingRecord: MaintenanceRecord?
    @State private var operationErrorMessage = ""
    @State private var isOperationErrorAlertPresented = false

    private var relatedLogs: [MaintenanceRecord] {
        maintenanceRecords.filter {
            $0.car != nil && MaintenanceItemCatalog.contains(itemID: itemID, in: $0.itemIDsRaw)
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
                            if let car = log.car {
                                Text(CarDisplayFormatter.name(car))
                                    .font(.headline)
                            }
                            Text("保养时间：\(AppDateContext.formatShortDate(log.date))")
                                .foregroundStyle(.secondary)
                            Text("里程：\(log.mileage) km")
                                .foregroundStyle(.secondary)
                            Text("总费用：\(CurrencyFormatter.value(log.cost))")
                                .foregroundStyle(.secondary)

                            Button("编辑该记录") {
                                editingRecord = log
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
        .sheet(item: $editingRecord) { log in
            AddMaintenanceRecordView(
                editingRecord: log,
                lockedItemID: itemID,
                limitToAppliedCar: false
            )
        }
        .alert("操作失败", isPresented: $isOperationErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
    }

    /// 删除关联保养记录。
    private func deleteRelatedLogs(at offsets: IndexSet) {
        let currentRelatedLogs = relatedLogs
        let targetLogs = offsets.compactMap { index in
            currentRelatedLogs.indices.contains(index) ? currentRelatedLogs[index] : nil
        }
        let targetLogIDs = Set(targetLogs.map(\.id))

        for log in targetLogs {
            var itemIDs = MaintenanceItemCatalog.parseItemIDs(log.itemIDsRaw)
            if itemIDs.count <= 1 {
                modelContext.delete(log)
                continue
            }

            if let firstMatchIndex = itemIDs.firstIndex(of: itemID) {
                itemIDs.remove(at: firstMatchIndex)
            } else {
                continue
            }

            if itemIDs.isEmpty {
                modelContext.delete(log)
            } else {
                /// 仅移除当前项目，避免误删同单其他保养项目。
                log.itemIDsRaw = MaintenanceItemCatalog.joinItemIDs(itemIDs)
                MaintenanceItemCatalog.syncCycleAndRelations(for: log, in: modelContext)
            }
        }

        if let editingRecord, targetLogIDs.contains(editingRecord.id) {
            self.editingRecord = nil
        }
        if let message = modelContext.saveOrLog("删除保养项目关联记录") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
        }
    }
}
