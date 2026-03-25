import Foundation
import Combine
import SwiftData

@MainActor
final class AddMaintenanceRecordViewModel: ObservableObject {
    let editingRecord: MaintenanceRecord?
    let lockedItemID: UUID?
    let limitToAppliedCar: Bool

    @Published var selectedCarID: UUID?
    @Published var selectedItems = Set<UUID>()
    @Published var maintenanceDate = AppDateContext.now()
    @Published var cost = "0"
    @Published var mileageWan = 0
    @Published var mileageQian = 0
    @Published var mileageBai = 0
    @Published var note = ""
    @Published var intervalConfirmDrafts: [MaintenanceIntervalDraft] = []
    @Published var isIntervalConfirmPresented = false
    @Published var isDuplicateCycleAlertPresented = false
    @Published var isIntervalConfirmDuplicateCycleAlertPresented = false
    @Published var duplicateCycleAlertMessage = ""
    @Published var saveErrorMessage = ""
    @Published var isSaveErrorAlertPresented = false
    @Published var isIntervalConfirmSaveErrorAlertPresented = false

    private var cars: [Car] = []
    private var serviceRecords: [MaintenanceRecord] = []
    private var serviceItemOptions: [MaintenanceItemOption] = []
    private var appliedCarIDRaw = ""

    private var initialEditDraftSnapshot: MaintenanceEditDraftSnapshot?
    private var hasLoadedInitialValues = false
    private var hasInitializedSplitDraft = false

    init(
        editingRecord: MaintenanceRecord? = nil,
        lockedItemID: UUID? = nil,
        limitToAppliedCar: Bool = true
    ) {
        self.editingRecord = editingRecord
        self.lockedItemID = lockedItemID
        self.limitToAppliedCar = limitToAppliedCar
    }

    var selectedCar: Car? {
        guard let selectedCarID else { return nil }
        return availableCars.first(where: { $0.id == selectedCarID })
    }

    var selectedCarDisplayText: String {
        guard let selectedCar else { return "未选择" }
        return "\(CarDisplayFormatter.name(selectedCar))（\(AppDateContext.formatShortDate(selectedCar.purchaseDate))）"
    }

    var scopedServiceItemOptions: [MaintenanceItemOption] {
        CoreConfig.scopedOptions(serviceItemOptions, carID: selectedCarID)
    }

    /// 合并“万 + 千 + 百”三段，得到保养发生时的公里数。
    var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian, bai: mileageBai)
    }

    /// 可选项目列表：先按车辆禁用状态过滤，再按统一规则排序。
    var availableItemOptions: [MaintenanceItemOption] {
        let visibleOptions = CoreConfig.filterDisabledOptions(
            scopedServiceItemOptions,
            disabledItemIDsRaw: selectedCar?.disabledItemIDsRaw ?? "",
            includeDisabled: editingRecord != nil
        )
        return CoreConfig.sortedOptions(
            visibleOptions,
            brand: selectedCar?.brand,
            modelName: selectedCar?.modelName
        )
    }

    var selectedItemsText: String {
        selectedItems.isEmpty ? "请选择（可多选）" : "已选\(selectedItems.count)项"
    }

    /// 按项目入口锁定编辑时，展示当前锁定项目名称。
    var lockedItemNameText: String {
        guard let lockedItemID else { return selectedItemsText }
        let names = CoreConfig.itemNames(from: [lockedItemID], options: scopedServiceItemOptions)
        return names.first ?? ""
    }

    /// 按项目入口编辑时，保养项目固定为当前项目。
    var isItemSelectionLocked: Bool {
        editingRecord != nil && lockedItemID != nil
    }

    /// 按项目入口编辑时，总费用为整单字段，设为只读避免误改。
    var isCostReadOnly: Bool {
        editingRecord != nil && lockedItemID != nil && !isSplitEditMode
    }

    /// 按项目编辑且跨周期时会拆单；拆单时允许填写新单费用和备注。
    var isSplitEditMode: Bool {
        guard let editingRecord, let lockedItemID else { return false }
        let originalItemIDs = CoreConfig.parseItemIDs(editingRecord.itemIDsRaw)
        guard originalItemIDs.contains(lockedItemID), originalItemIDs.count > 1 else { return false }
        guard let selectedCarID, let selectedCar = availableCars.first(where: { $0.id == selectedCarID }) else { return false }
        let targetCycleKey = MaintenanceRecord.cycleKey(carID: selectedCar.id, date: maintenanceDate)
        return editingRecord.cycleKey != targetCycleKey
    }

    /// 合法费用：非负，最多 2 位小数。
    var parsedCost: Double? {
        guard !cost.isEmpty, let value = Double(cost), value >= 0 else { return nil }
        return value
    }

    /// 基础输入校验，避免非法数据入库。
    var canSave: Bool {
        guard selectedCarID != nil, !selectedItems.isEmpty else { return false }
        if let lockedItemID, isItemSelectionLocked {
            guard scopedServiceItemOptions.contains(where: { $0.id == lockedItemID }) else { return false }
        }
        if isCostReadOnly { return true }
        return parsedCost != nil
    }

    /// 编辑场景下，只有草稿发生变更才允许保存。
    var canSubmit: Bool {
        guard canSave else { return false }
        guard editingRecord != nil else { return true }
        return hasDraftChanges
    }

    var orderedSelectedItemIDs: [UUID] {
        availableItemOptions.map(\.id).filter { selectedItems.contains($0) }
    }

    var intervalConfirmIntroductionText: String {
        "请确认本次保养项目的下次提醒间隔，点击保存后会同时保存保养记录与默认提醒值。"
    }

    var isEditing: Bool {
        editingRecord != nil
    }

    var hasAvailableCars: Bool {
        availableCars.isEmpty == false
    }

    func normalizedAppliedCarRaw(_ rawID: String, cars: [Car]) -> String {
        guard limitToAppliedCar else { return rawID }
        return AppliedCarContext.normalizedRawID(rawID: rawID, cars: cars)
    }

    func updateSources(
        cars: [Car],
        serviceRecords: [MaintenanceRecord],
        serviceItemOptions: [MaintenanceItemOption],
        appliedCarIDRaw: String
    ) {
        self.cars = cars
        self.serviceRecords = serviceRecords
        self.serviceItemOptions = serviceItemOptions
        self.appliedCarIDRaw = appliedCarIDRaw

        loadInitialValuesIfNeeded()
        ensureSelectedCarIsValid()

        if editingRecord != nil, initialEditDraftSnapshot == nil {
            initialEditDraftSnapshot = currentEditDraftSnapshot
        }
    }

    /// 切换多选项状态。
    func toggleItem(_ itemID: UUID) {
        guard !isItemSelectionLocked else { return }
        if selectedItems.contains(itemID) {
            selectedItems.remove(itemID)
        } else {
            selectedItems.insert(itemID)
        }
    }

    func onSelectedCarChanged(_ newValue: UUID?) {
        applyDefaultMileageIfNeeded(for: newValue)
    }

    func onCostInputFocusChanged(isFocused: Bool) {
        guard isFocused else { return }
        guard !isCostReadOnly else { return }
        guard cost == "0" else { return }
        cost = ""
    }

    func onCostChanged(_ newValue: String) {
        cost = sanitizeCostInput(newValue)
    }

    func onSplitEditModeChanged(_ newValue: Bool) {
        if newValue {
            if hasInitializedSplitDraft == false {
                cost = "0"
                note = ""
                hasInitializedSplitDraft = true
            }
        } else {
            hasInitializedSplitDraft = false
        }
    }

    /// 新增场景进入“确认下次间隔”步骤，不在此时落库。
    func proceedToIntervalConfirmation() {
        prepareIntervalConfirmationDrafts(for: orderedSelectedItemIDs)
        isIntervalConfirmPresented = true
    }

    /// 在确认页点击“保存”后，一次性保存保养记录和提醒默认值。
    func applyIntervalConfirmationAndDismiss(
        modelContext: ModelContext,
        dismiss: () -> Void
    ) {
        saveRecord(modelContext: modelContext, dismiss: dismiss, applyIntervalChanges: true)
    }

    /// 重复周期时直接跳转到“保养记录”页。
    func openDuplicateCycleRecordEditor() {
        AppNavigationContext.requestNavigation(to: .records)
    }

    func formattedYearInterval(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    /// 根据选择的车辆写入保养记录；新增场景在确认页保存时才真正落库。
    func saveRecord(
        modelContext: ModelContext,
        dismiss: () -> Void,
        applyIntervalChanges: Bool = false
    ) {
        guard
            let selectedCarID,
            let selectedCar = availableCars.first(where: { $0.id == selectedCarID })
        else {
            return
        }
        if !isCostReadOnly, parsedCost == nil {
            return
        }
        let finalCost = parsedCost ?? editingRecord?.cost ?? 0
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetCycleKey = MaintenanceRecord.cycleKey(carID: selectedCar.id, date: maintenanceDate)
        let existingCycleRecord = serviceRecords.first { record in
            guard record.id != editingRecord?.id else { return false }
            guard let carID = record.car?.id else { return false }
            return MaintenanceRecord.cycleKey(carID: carID, date: record.date) == targetCycleKey
        }

        if let editingRecord {
            let recordBefore = AppDatabaseSnapshot.maintenanceRecord(editingRecord)
            if let existingCycleRecord {
                duplicateCycleAlertMessage = "“\(AppDateContext.formatShortDate(existingCycleRecord.date))”已存在保养记录，请到保养页编辑该日期记录。"
                if applyIntervalChanges {
                    isIntervalConfirmDuplicateCycleAlertPresented = true
                } else {
                    isDuplicateCycleAlertPresented = true
                }
                return
            }
            if let lockedItemID, isItemSelectionLocked {
                guard applyLockedItemEdit(
                    modelContext: modelContext,
                    editingRecord: editingRecord,
                    lockedItemID: lockedItemID,
                    selectedCar: selectedCar,
                    splitCost: finalCost,
                    splitNote: normalizedNote
                ) else {
                    return
                }
            } else {
                let itemIDsRaw = CoreConfig.joinItemIDs(orderedSelectedItemIDs)
                editingRecord.date = maintenanceDate
                editingRecord.itemIDsRaw = itemIDsRaw
                editingRecord.cost = finalCost
                editingRecord.mileage = currentMileage
                editingRecord.note = normalizedNote
                editingRecord.car = selectedCar
                editingRecord.cycleKey = targetCycleKey
                CoreConfig.syncCycleAndRelations(for: editingRecord, in: modelContext)
            }
            AppDatabaseAuditLogger.logUpdate(
                entity: "MaintenanceRecord",
                before: recordBefore,
                after: AppDatabaseSnapshot.maintenanceRecord(editingRecord)
            )
        } else {
            if let existingCycleRecord {
                duplicateCycleAlertMessage = "“\(AppDateContext.formatShortDate(existingCycleRecord.date))”已存在保养记录，请到记录页编辑该日期记录。"
                if applyIntervalChanges {
                    isIntervalConfirmDuplicateCycleAlertPresented = true
                } else {
                    isDuplicateCycleAlertPresented = true
                }
            } else {
                let itemIDsRaw = CoreConfig.joinItemIDs(orderedSelectedItemIDs)
                let record = MaintenanceRecord(
                    date: maintenanceDate,
                    itemIDsRaw: itemIDsRaw,
                    cost: finalCost,
                    mileage: currentMileage,
                    note: normalizedNote,
                    car: selectedCar
                )
                modelContext.insertWithAudit(record)
                CoreConfig.syncCycleAndRelations(for: record, in: modelContext)
            }
            if isDuplicateCycleAlertPresented || isIntervalConfirmDuplicateCycleAlertPresented {
                return
            }
        }

        if applyIntervalChanges {
            applyIntervalConfirmationToOptions()
        }

        /// 保存保养记录后，车辆当前里程与表单里程取较大值，避免里程回退。
        if currentMileage > selectedCar.mileage {
            let carBefore = AppDatabaseSnapshot.car(selectedCar)
            selectedCar.mileage = currentMileage
            AppDatabaseAuditLogger.logUpdate(
                entity: "Car",
                before: carBefore,
                after: AppDatabaseSnapshot.car(selectedCar)
            )
        }

        if let message = modelContext.saveOrLog("保存保养记录") {
            saveErrorMessage = message
            if applyIntervalChanges {
                isIntervalConfirmSaveErrorAlertPresented = true
            } else {
                isSaveErrorAlertPresented = true
            }
            return
        }
        if applyIntervalChanges {
            AppNavigationContext.requestNavigation(to: .reminder)
            return
        }
        dismiss()
    }

    private var availableCars: [Car] {
        guard limitToAppliedCar else { return cars }
        guard let appliedCarID = AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars) else {
            return []
        }
        return cars.filter { $0.id == appliedCarID }
    }

    private var hasDraftChanges: Bool {
        guard let initialEditDraftSnapshot else { return false }
        return initialEditDraftSnapshot != currentEditDraftSnapshot
    }

    private var currentEditDraftSnapshot: MaintenanceEditDraftSnapshot {
        let normalizedDate = Calendar.current.startOfDay(for: maintenanceDate)
        return MaintenanceEditDraftSnapshot(
            selectedCarID: selectedCarID,
            selectedItems: selectedItems,
            maintenanceDate: normalizedDate,
            mileage: currentMileage,
            cost: parsedCost ?? editingRecord?.cost ?? 0,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func loadInitialValuesIfNeeded() {
        guard !hasLoadedInitialValues else { return }
        hasLoadedInitialValues = true

        if let editingRecord {
            selectedCarID = editingRecord.car?.id ?? availableCars.first?.id
            if let lockedItemID {
                selectedItems = [lockedItemID]
            } else {
                selectedItems = Set(CoreConfig.parseItemIDs(editingRecord.itemIDsRaw))
            }
            maintenanceDate = editingRecord.date
            cost = formatCost(editingRecord.cost)
            let segments = MileageSegmentFormatter.segments(from: editingRecord.mileage)
            mileageWan = segments.wan
            mileageQian = segments.qian
            mileageBai = segments.bai
            note = editingRecord.note
            return
        }

        selectedCarID = availableCars.first?.id
        cost = "0"
        applyDefaultMileageIfNeeded(for: selectedCarID)
    }

    /// 过滤非法字符并限制 2 位小数。
    private func sanitizeCostInput(_ raw: String) -> String {
        let filtered = raw.filter { $0.isNumber || $0 == "." }
        if filtered.isEmpty { return "" }

        var result = ""
        var hasDot = false
        var fractionCount = 0

        for char in filtered {
            if char == "." {
                if hasDot { continue }
                hasDot = true
                if result.isEmpty { result = "0" }
                result.append(char)
                continue
            }

            if hasDot {
                if fractionCount >= 2 { continue }
                fractionCount += 1
            }
            result.append(char)
        }

        return result
    }

    /// 编辑态费用展示：最多两位小数，去掉无效尾零。
    private func formatCost(_ value: Double) -> String {
        if value == 0 { return "0" }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }

    /// 新增场景默认里程：取车辆信息中的当前里程，无车辆时为 0。
    private func applyDefaultMileageIfNeeded(for carID: UUID?) {
        guard editingRecord == nil else { return }

        guard let carID else {
            mileageWan = 0
            mileageQian = 0
            mileageBai = 0
            return
        }

        let carMileage = availableCars.first(where: { $0.id == carID })?.mileage ?? 0
        let segments = MileageSegmentFormatter.segments(from: carMileage)
        mileageWan = segments.wan
        mileageQian = segments.qian
        mileageBai = segments.bai
    }

    /// 确保当前表单选中车辆始终落在可用范围内。
    private func ensureSelectedCarIsValid() {
        guard availableCars.contains(where: { $0.id == selectedCarID }) == false else { return }
        selectedCarID = availableCars.first?.id
    }

    /// 按项目入口编辑时，若原记录包含多个项目，则拆分出当前项目单独保存，避免联动修改同单其他项目。
    private func applyLockedItemEdit(
        modelContext: ModelContext,
        editingRecord: MaintenanceRecord,
        lockedItemID: UUID,
        selectedCar: Car,
        splitCost: Double,
        splitNote: String
    ) -> Bool {
        let recordBefore = AppDatabaseSnapshot.maintenanceRecord(editingRecord)
        let originalItemIDs = CoreConfig.parseItemIDs(editingRecord.itemIDsRaw)
        guard let lockedIndex = originalItemIDs.firstIndex(of: lockedItemID) else { return false }

        let originalCycleKey = editingRecord.cycleKey
        let targetCycleKey = MaintenanceRecord.cycleKey(carID: selectedCar.id, date: maintenanceDate)
        if originalItemIDs.count == 1 || originalCycleKey == targetCycleKey {
            editingRecord.date = maintenanceDate
            editingRecord.mileage = currentMileage
            editingRecord.car = selectedCar
            editingRecord.cycleKey = targetCycleKey
            editingRecord.itemIDsRaw = CoreConfig.joinItemIDs(originalItemIDs)
            CoreConfig.syncCycleAndRelations(for: editingRecord, in: modelContext)
            AppDatabaseAuditLogger.logUpdate(
                entity: "MaintenanceRecord",
                before: recordBefore,
                after: AppDatabaseSnapshot.maintenanceRecord(editingRecord)
            )
            return true
        }

        var remainingItemIDs = originalItemIDs
        remainingItemIDs.remove(at: lockedIndex)
        editingRecord.itemIDsRaw = CoreConfig.joinItemIDs(remainingItemIDs)
        CoreConfig.syncCycleAndRelations(for: editingRecord, in: modelContext)

        /// 拆分记录时，原单仅剔除当前项目；新单费用默认 0，可在表单中改写。
        let splitRecord = MaintenanceRecord(
            date: maintenanceDate,
            itemIDsRaw: CoreConfig.joinItemIDs([lockedItemID]),
            cost: splitCost,
            mileage: currentMileage,
            note: splitNote,
            car: selectedCar
        )
        modelContext.insertWithAudit(splitRecord)
        CoreConfig.syncCycleAndRelations(for: splitRecord, in: modelContext)
        AppDatabaseAuditLogger.logUpdate(
            entity: "MaintenanceRecord",
            before: recordBefore,
            after: AppDatabaseSnapshot.maintenanceRecord(editingRecord)
        )
        return true
    }

    /// 构建“下次间隔确认”草稿：仅针对本次选择的保养项目。
    private func prepareIntervalConfirmationDrafts(for itemIDs: [UUID]) {
        var drafts: [MaintenanceIntervalDraft] = []

        for itemID in itemIDs {
            guard let option = scopedServiceItemOptions.first(where: { $0.id == itemID }) else {
                continue
            }

            let defaultMileage = option.mileageInterval == 0 ? 5_000 : option.mileageInterval
            let defaultMonths = max(1, option.monthInterval)
            let defaultYears = max(0.5, Double(defaultMonths) / 12.0)

            drafts.append(
                MaintenanceIntervalDraft(
                    id: option.id,
                    name: option.name,
                    remindByMileage: option.remindByMileage,
                    mileageInterval: defaultMileage,
                    remindByTime: option.remindByTime,
                    yearInterval: defaultYears
                )
            )
        }

        intervalConfirmDrafts = drafts
    }

    /// 把确认结果回写为全局默认提醒间隔。
    private func applyIntervalConfirmationToOptions() {
        for draft in intervalConfirmDrafts {
            guard let option = scopedServiceItemOptions.first(where: { $0.id == draft.id }) else {
                continue
            }

            if option.remindByMileage {
                option.mileageInterval = max(1, draft.mileageInterval)
            }

            if option.remindByTime {
                let months = max(1, Int((draft.yearInterval * 12).rounded()))
                option.monthInterval = months
            }
        }
    }
}
