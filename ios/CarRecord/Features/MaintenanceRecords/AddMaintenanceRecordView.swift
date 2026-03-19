import SwiftUI
import SwiftData
import UIKit

/// 新增/编辑保养页：支持下拉多选项目、自定义项目、保养时间和里程弹窗选择。
struct AddMaintenanceRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Car.purchaseDate, order: .reverse) private var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) private var maintenanceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) private var appliedCarIDRaw = ""

    let editingRecord: MaintenanceRecord?
    let lockedItemID: UUID?
    let limitToAppliedCar: Bool

    @State private var selectedCarID: UUID?
    @State private var selectedItems = Set<UUID>()
    @State private var maintenanceDate = AppDateContext.now()
    @State private var draftMaintenanceDate = AppDateContext.now()
    /// 新增记录默认总费用为 0，避免首次进入为空导致无法直接保存。
    @State private var cost = "0"
    @State private var mileageWan = 0
    @State private var mileageQian = 0
    @State private var mileageBai = 0
    @State private var note = ""
    @State private var hasLoadedInitialValues = false
    @State private var activePickerSheet: MaintenancePickerSheet?
    @State private var intervalConfirmDrafts: [MaintenanceIntervalDraft] = []
    @State private var isIntervalConfirmPresented = false
    @State private var isDuplicateCycleAlertPresented = false
    @State private var duplicateCycleAlertMessage = ""
    @State private var saveErrorMessage = ""
    @State private var isSaveErrorAlertPresented = false
    @State private var hasInitializedSplitDraft = false
    @FocusState private var focusedField: FocusField?

    init(
        editingRecord: MaintenanceRecord? = nil,
        lockedItemID: UUID? = nil,
        limitToAppliedCar: Bool = true
    ) {
        self.editingRecord = editingRecord
        self.lockedItemID = lockedItemID
        self.limitToAppliedCar = limitToAppliedCar
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("车辆信息") {
                    if availableCars.isEmpty {
                        Text("请先添加车辆，再记录保养。")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("车辆", selection: $selectedCarID) {
                            ForEach(availableCars) { car in
                                Text("\(CarDisplayFormatter.name(car))（\(AppDateContext.formatShortDate(car.purchaseDate))）")
                                    .tag(Optional(car.id))
                            }
                        }
                    }

                    Button {
                        draftMaintenanceDate = maintenanceDate
                        presentPickerSheet(.maintenanceDate)
                    } label: {
                        HStack {
                            Text("保养时间")
                            Spacer()
                            Text(AppDateContext.formatShortDate(maintenanceDate))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentPickerSheet(.mileage)
                    } label: {
                        HStack {
                            Text("当前里程")
                            Spacer()
                            Text(MileageSegmentFormatter.text(wan: mileageWan, qian: mileageQian, bai: mileageBai))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section("保养项目") {
                    if isItemSelectionLocked {
                        HStack {
                            Text("选择项目")
                            Spacer()
                            Text(lockedItemNameText)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Button {
                            presentPickerSheet(.maintenanceItems)
                        } label: {
                            HStack {
                                Text("选择项目")
                                Spacer()
                                Text(selectedItemsText)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !isCostReadOnly {
                    Section("保养费用") {
                        HStack {
                            Text("总费用")
                            Spacer()
                            TextField("请输入", text: $cost)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .cost)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .cost
                        }

                        TextField("备注（选填）", text: $note)
                            .focused($focusedField, equals: .note)
                            .submitLabel(.done)
                            .onSubmit {
                                closeInputEditors()
                            }
                    }
                }
            }
            .navigationTitle(editingRecord == nil ? "新增保养" : "编辑保养")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isAnyInputActive {
                        Button(editingRecord == nil ? "下一步" : "保存") {
                            if editingRecord == nil {
                                proceedToIntervalConfirmation()
                            } else {
                                saveRecord()
                            }
                        }
                        .disabled(!canSave)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .cost, !isCostReadOnly {
                        Spacer()
                        Button("保存") {
                            closeInputEditors()
                        }
                    }
                }
            }
            .onAppear {
                syncAppliedCarSelectionIfNeeded()
                loadInitialValuesIfNeeded()
                ensureSelectedCarIsValid()
            }
            .onChange(of: cars.map(\.id)) { _, _ in
                syncAppliedCarSelectionIfNeeded()
                ensureSelectedCarIsValid()
            }
            .onChange(of: selectedCarID) { _, newValue in
                applyDefaultMileageIfNeeded(for: newValue)
            }
            .onChange(of: focusedField) { _, newValue in
                guard newValue == .cost else { return }
                guard !isCostReadOnly else { return }
                guard cost == "0" else { return }
                cost = ""
            }
            .onChange(of: cost) { _, newValue in
                cost = sanitizeCostInput(newValue)
            }
            .onChange(of: isSplitEditMode) { _, newValue in
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
            .sheet(item: $activePickerSheet) { sheet in
                switch sheet {
                case .maintenanceDate:
                    maintenanceDatePickerSheet
                case .mileage:
                    mileagePickerSheet
                case .maintenanceItems:
                    maintenanceItemsPickerSheet
                }
            }
            .navigationDestination(isPresented: $isIntervalConfirmPresented) {
                intervalConfirmSheet
            }
            .alert("已存在同日记录", isPresented: $isDuplicateCycleAlertPresented) {
                Button("去编辑") {
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(duplicateCycleAlertMessage)
            }
            .alert("保存失败", isPresented: $isSaveErrorAlertPresented) {
                Button("我知道了", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    @ViewBuilder
    private var maintenanceDatePickerSheet: some View {
        DayDatePickerSheetView(
            title: "选择保养时间",
            label: "保养时间",
            draftDate: $draftMaintenanceDate,
            currentDate: maintenanceDate,
            onApply: { newValue in
                maintenanceDate = newValue
                activePickerSheet = nil
            },
            onCancel: { activePickerSheet = nil }
        )
    }

    @ViewBuilder
    private var mileagePickerSheet: some View {
        MileagePickerSheetView(
            title: "选择当前里程",
            wan: $mileageWan,
            qian: $mileageQian,
            bai: $mileageBai,
            onCancel: { activePickerSheet = nil },
            onConfirm: { activePickerSheet = nil }
        )
    }

    @ViewBuilder
    private var maintenanceItemsPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(availableItemOptions) { option in
                    Button {
                        toggleItem(option.id)
                    } label: {
                        HStack {
                            Text(option.name)
                            Spacer()
                            if selectedItems.contains(option.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("选择保养项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        activePickerSheet = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var intervalConfirmSheet: some View {
        Form {
            Section {
                Text("请确认本次保养项目的下次提醒间隔，点击保存后会同时保存保养记录与默认提醒值。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(intervalConfirmDrafts.indices, id: \.self) { index in
                Section(intervalConfirmDrafts[index].name) {
                    if intervalConfirmDrafts[index].remindByMileage {
                        Stepper(value: $intervalConfirmDrafts[index].mileageInterval, in: 1_000...100_000, step: 500) {
                            Text("下次里程间隔：\(intervalConfirmDrafts[index].mileageInterval) km")
                        }
                    }

                    if intervalConfirmDrafts[index].remindByTime {
                        Stepper(value: $intervalConfirmDrafts[index].yearInterval, in: 0.5...10, step: 0.5) {
                            Text("下次时间间隔：\(formattedYearInterval(intervalConfirmDrafts[index].yearInterval))年")
                        }
                    }

                    if intervalConfirmDrafts[index].remindByMileage == false &&
                        intervalConfirmDrafts[index].remindByTime == false {
                        Text("该项目未开启提醒方式。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("确认下次间隔")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("返回") {
                    isIntervalConfirmPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    applyIntervalConfirmationAndDismiss()
                }
            }
        }
    }

    /// 合并“万 + 千 + 百”三段，得到保养发生时的公里数。
    private var currentMileage: Int {
        MileageSegmentFormatter.mileage(wan: mileageWan, qian: mileageQian, bai: mileageBai)
    }

    /// 可选项目列表排序规则：
    /// 1) 无保养记录时：机油/汽油发动机清洁剂/空调滤芯优先，其余按自然顺序。
    /// 2) 有保养记录时：按项目被保养次数倒序，未保养项目按自然顺序。
    private var availableItemOptions: [MaintenanceItemOption] {
        CoreConfig.sortedSelectionOptions(
            options: maintenanceItemOptions,
            records: maintenanceRecords
        )
    }

    private var selectedItemsText: String {
        selectedItems.isEmpty ? "请选择" : "已选\(selectedItems.count)项"
    }

    /// 按项目入口锁定编辑时，展示当前锁定项目名称。
    private var lockedItemNameText: String {
        guard let lockedItemID else { return selectedItemsText }
        let names = CoreConfig.itemNames(from: [lockedItemID], options: maintenanceItemOptions)
        return names.first ?? ""
    }

    /// 按项目入口编辑时，保养项目固定为当前项目。
    private var isItemSelectionLocked: Bool {
        editingRecord != nil && lockedItemID != nil
    }

    /// 按项目入口编辑时，总费用为整单字段，设为只读避免误改。
    private var isCostReadOnly: Bool {
        editingRecord != nil && lockedItemID != nil && !isSplitEditMode
    }

    /// 按项目编辑且跨周期时会拆单；拆单时允许填写新单费用和备注。
    private var isSplitEditMode: Bool {
        guard let editingRecord, let lockedItemID else { return false }
        let originalItemIDs = CoreConfig.parseItemIDs(editingRecord.itemIDsRaw)
        guard originalItemIDs.contains(lockedItemID), originalItemIDs.count > 1 else { return false }
        guard let selectedCarID, let selectedCar = availableCars.first(where: { $0.id == selectedCarID }) else { return false }
        let targetCycleKey = MaintenanceRecord.cycleKey(carID: selectedCar.id, date: maintenanceDate)
        return editingRecord.cycleKey != targetCycleKey
    }

    /// 合法费用：非负，最多 2 位小数。
    private var parsedCost: Double? {
        guard !cost.isEmpty, let value = Double(cost), value >= 0 else { return nil }
        return value
    }

    /// 基础输入校验，避免非法数据入库。
    private var canSave: Bool {
        guard selectedCarID != nil, !selectedItems.isEmpty else { return false }
        if let lockedItemID, isItemSelectionLocked {
            guard maintenanceItemOptions.contains(where: { $0.id == lockedItemID }) else { return false }
        }
        if isCostReadOnly { return true }
        return parsedCost != nil
    }

    /// 当前是否处于任意输入态：用于避免导航栏“保存”与键盘操作冲突。
    private var isAnyInputActive: Bool {
        focusedField != nil
    }

    /// 新增场景进入“确认下次间隔”步骤，不在此时落库。
    private func proceedToIntervalConfirmation() {
        closeInputEditors()
        prepareIntervalConfirmationDrafts(for: orderedSelectedItemIDs)
        isIntervalConfirmPresented = true
    }

    /// 根据选择的车辆写入保养记录；新增场景在确认页保存时才真正落库。
    private func saveRecord(applyIntervalChanges: Bool = false) {
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
        let existingCycleRecord = maintenanceRecords.first { record in
            guard record.id != editingRecord?.id else { return false }
            guard let carID = record.car?.id else { return false }
            return MaintenanceRecord.cycleKey(carID: carID, date: record.date) == targetCycleKey
        }

        if let editingRecord {
            if let existingCycleRecord {
                duplicateCycleAlertMessage = "“\(AppDateContext.formatShortDate(existingCycleRecord.date))”已存在保养记录，请到记录页编辑该日期记录。"
                isDuplicateCycleAlertPresented = true
                return
            }
            if let lockedItemID, isItemSelectionLocked {
                guard applyLockedItemEdit(
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
        } else {
            if let existingCycleRecord {
                duplicateCycleAlertMessage = "“\(AppDateContext.formatShortDate(existingCycleRecord.date))”已存在保养记录，请到记录页编辑该日期记录。"
                isDuplicateCycleAlertPresented = true
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
                modelContext.insert(record)
                CoreConfig.syncCycleAndRelations(for: record, in: modelContext)
            }
            if isDuplicateCycleAlertPresented {
                return
            }
        }

        if applyIntervalChanges {
            applyIntervalConfirmationToOptions()
        }

        /// 当保养日期是今天时，自动同步车辆当前里程。
        if AppDateContext.calendar.isDate(maintenanceDate, inSameDayAs: AppDateContext.now()) {
            selectedCar.mileage = currentMileage
        }

        if let message = modelContext.saveOrLog("保存保养记录") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
            return
        }
        dismiss()
    }

    /// 按项目入口编辑时，若原记录包含多个项目，则拆分出当前项目单独保存，避免联动修改同单其他项目。
    private func applyLockedItemEdit(
        editingRecord: MaintenanceRecord,
        lockedItemID: UUID,
        selectedCar: Car,
        splitCost: Double,
        splitNote: String
    ) -> Bool {
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
        modelContext.insert(splitRecord)
        CoreConfig.syncCycleAndRelations(for: splitRecord, in: modelContext)
        return true
    }

    /// 编辑场景回填原值，新增场景则选中第一辆车。
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
            draftMaintenanceDate = editingRecord.date
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
        draftMaintenanceDate = maintenanceDate
        applyDefaultMileageIfNeeded(for: selectedCarID)
    }

    /// 切换多选项状态。
    private func toggleItem(_ itemID: UUID) {
        guard !isItemSelectionLocked else { return }
        if selectedItems.contains(itemID) {
            selectedItems.remove(itemID)
        } else {
            selectedItems.insert(itemID)
        }
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

    /// 构建“下次间隔确认”草稿：仅针对本次选择的保养项目。
    private func prepareIntervalConfirmationDrafts(for itemIDs: [UUID]) {
        var drafts: [MaintenanceIntervalDraft] = []

        for itemID in itemIDs {
            guard let option = maintenanceItemOptions.first(where: { $0.id == itemID }) else {
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

    /// 当前选中项目按展示顺序生成，保证落库顺序稳定。
    private var orderedSelectedItemIDs: [UUID] {
        availableItemOptions.map(\.id).filter { selectedItems.contains($0) }
    }

    /// 把确认结果回写为全局默认提醒间隔。
    private func applyIntervalConfirmationToOptions() {
        for draft in intervalConfirmDrafts {
            guard let option = maintenanceItemOptions.first(where: { $0.id == draft.id }) else {
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

    /// 在确认页点击“保存”后，一次性保存保养记录和提醒默认值。
    private func applyIntervalConfirmationAndDismiss() {
        saveRecord(applyIntervalChanges: true)
    }

    /// 统一“年”文案格式：整数不带小数，半年度显示 0.5。
    private func formattedYearInterval(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    /// 统一拉起弹窗：先收起键盘，避免出现“要点几次才弹出”的交互问题。
    private func presentPickerSheet(_ sheet: MaintenancePickerSheet) {
        closeInputEditors()
        DispatchQueue.main.async {
            activePickerSheet = sheet
        }
    }

    /// 统一收起当前输入态：用于弹窗切换和键盘右上角“保存”按钮。
    private func closeInputEditors() {
        focusedField = nil
        hideKeyboard()
    }

    /// 主动结束当前输入，避免键盘占位视图约束冲突。
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// 新增/编辑入口可用车辆：默认仅保留“已应用车型”；管理页可关闭该限制。
    private var availableCars: [Car] {
        guard limitToAppliedCar else { return cars }
        guard let appliedCarID = AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars) else {
            return []
        }
        return cars.filter { $0.id == appliedCarID }
    }

    /// 仅在隔离模式下修正持久化车型ID，避免引用已删除车辆。
    private func syncAppliedCarSelectionIfNeeded() {
        guard limitToAppliedCar else { return }
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 确保当前表单选中车辆始终落在可用范围内。
    private func ensureSelectedCarIsValid() {
        guard availableCars.contains(where: { $0.id == selectedCarID }) == false else { return }
        selectedCarID = availableCars.first?.id
    }
}

/// 当前页面内需要拉起的弹窗类型。
private enum MaintenancePickerSheet: Identifiable {
    case maintenanceDate
    case mileage
    case maintenanceItems

    var id: String {
        switch self {
        case .maintenanceDate:
            return "maintenanceDate"
        case .mileage:
            return "mileage"
        case .maintenanceItems:
            return "maintenanceItems"
        }
    }
}

/// 输入焦点：用于区分当前是“总费用”还是“备注”在编辑。
private enum FocusField {
    case cost
    case note
}

/// 保存后间隔确认草稿：用于回写保养项目的全局默认提醒间隔。
private struct MaintenanceIntervalDraft: Identifiable {
    let id: UUID
    let name: String
    let remindByMileage: Bool
    var mileageInterval: Int
    let remindByTime: Bool
    var yearInterval: Double
}
