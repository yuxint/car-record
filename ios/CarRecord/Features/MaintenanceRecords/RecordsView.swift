import SwiftUI
import SwiftData

/// 保养记录列表页：读取本地保养记录并支持新增。
struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse)
    private var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse)
    private var maintenanceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward)
    private var maintenanceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) private var appliedCarIDRaw = ""

    @State private var displayMode: LogDisplayMode = .byDate
    @State private var editingTarget: MaintenanceRecordEditTarget?
    @State private var cycleFilters = LogFilterState()
    @State private var itemFilters = LogFilterState()
    @State private var isCycleFilterExpanded = false
    @State private var isItemFilterExpanded = false
    @State private var selectionSheetTarget: FilterSelectionSheetTarget?
    @State private var selectionDraftIDs: Set<UUID> = []
    @State private var hasInteractedWithSelectionDraft = false
    @State private var saveErrorMessage = ""
    @State private var isSaveErrorAlertPresented = false

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

            if scopedMaintenanceRecords.isEmpty {
                Text("还没有保养记录。")
                    .foregroundStyle(.secondary)
            } else {
                if displayMode == .byDate {
                    Section {
                        filterPanel(
                            filters: $cycleFilters,
                            mode: .byDate,
                            isExpanded: $isCycleFilterExpanded
                        )
                    }

                    Section(cycleSectionTitle) {
                        if filteredDateGroups.isEmpty {
                            Text("暂无符合筛选条件的记录。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredDateGroups) { group in
                                dateGroupRow(group)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteRecords(group.records)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    Section {
                        filterPanel(
                            filters: $itemFilters,
                            mode: .byItem,
                            isExpanded: $isItemFilterExpanded
                        )
                    }

                    Section(itemSectionTitle) {
                        if filteredItemRows.isEmpty {
                            Text("暂无符合筛选条件的记录。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredItemRows) { row in
                                itemRow(row)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteItemRow(row)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("保养记录")
        .sheet(item: $editingTarget) { target in
            AddMaintenanceRecordView(
                editingRecord: target.record,
                lockedItemID: target.lockedItemID
            )
        }
        .sheet(item: $selectionSheetTarget) { target in
            selectionSheet(target)
        }
        .alert("操作失败", isPresented: $isSaveErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .onAppear {
            syncAppliedCarSelection()
            normalizeFilterSelectionsForAppliedCar()
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            syncAppliedCarSelection()
            normalizeFilterSelectionsForAppliedCar()
        }
    }

    /// 分区标题：展示“按周期”统计数量（按分组条数统计）。
    private var cycleSectionTitle: String {
        "按周期展示（\(filteredDateGroups.count)条）"
    }

    /// 分区标题：展示“按项目”统计数量（按项目行数统计）。
    private var itemSectionTitle: String {
        "按保养项目展示（\(filteredItemRows.count)条）"
    }

    /// “按周期”视图使用的过滤结果：先按记录过滤，再按天聚合。
    private var filteredDateGroups: [MaintenanceDateGroup] {
        let recordsForGrouping = scopedMaintenanceRecords.filter { record in
            guard record.car != nil else { return false }
            return matchesCycleFilters(record: record, filters: cycleFilters)
        }
        let grouped = buildDateGroups(from: recordsForGrouping)
        return grouped.filter { group in
            matchesCycleItemFilter(group: group, selectedItemIDs: cycleFilters.selectedItemIDs)
        }
    }

    /// “按项目”视图使用的过滤结果：先按通用条件过滤记录，再按项目展开并做项目筛选。
    private var filteredItemRows: [MaintenanceItemRow] {
        buildItemRows(
            from: scopedMaintenanceRecords.filter { $0.car != nil }
        )
            .filter { row in
                matchesItemSelection(rowItemID: row.itemID, selectedItemIDs: itemFilters.selectedItemIDs)
            }
    }

    /// 按日期分组并倒序，自动合并同一天的保养记录。
    private func buildDateGroups(from records: [MaintenanceRecord]) -> [MaintenanceDateGroup] {
        let grouped = Dictionary(grouping: records) { record in
            AppDateContext.calendar.startOfDay(for: record.date)
        }

        return grouped
            .map { date, groupRecords in
                var seenItemIDs = Set<UUID>()
                let uniqueItemIDs = groupRecords
                    .flatMap { MaintenanceItemCatalog.parseItemIDs($0.itemIDsRaw) }
                    .filter { itemID in
                        if seenItemIDs.contains(itemID) {
                            return false
                        }
                        seenItemIDs.insert(itemID)
                        return true
                    }
                let nameByID = Dictionary(uniqueKeysWithValues: maintenanceItemOptions.map { ($0.id, $0.name) })
                let sortedItemIDs = uniqueItemIDs.sorted { lhs, rhs in
                    let lhsOrder = naturalItemOrderIndexByID[lhs, default: Int.max]
                    let rhsOrder = naturalItemOrderIndexByID[rhs, default: Int.max]
                    if lhsOrder != rhsOrder {
                        return lhsOrder < rhsOrder
                    }
                    return lhs.uuidString < rhs.uuidString
                }
                let sortedItemNames = sortedItemIDs.compactMap { nameByID[$0] }
                return MaintenanceDateGroup(
                    date: date,
                    records: groupRecords.sorted { lhs, rhs in
                        if lhs.date != rhs.date {
                            return lhs.date > rhs.date
                        }
                        if lhs.mileage != rhs.mileage {
                            return lhs.mileage > rhs.mileage
                        }
                        return lhs.id.uuidString < rhs.id.uuidString
                    },
                    itemSummary: sortedItemNames.isEmpty ? "未标注项目" : sortedItemNames.joined(separator: "、")
                )
            }
            .sorted { $0.date > $1.date } 
    }

    /// 展开“按项目展示”时使用的行数据：
    /// 1) 按保养时间倒序；
    /// 2) 同一保养时间时按里程倒序，确保高里程排前面。
    private func buildItemRows(from records: [MaintenanceRecord]) -> [MaintenanceItemRow] {
        let nameByID = Dictionary(uniqueKeysWithValues: maintenanceItemOptions.map { ($0.id, $0.name) })

        return records.flatMap { record in
            let itemIDs = MaintenanceItemCatalog.parseItemIDs(record.itemIDsRaw)
            guard itemIDs.isEmpty == false else { return [MaintenanceItemRow]() }
            guard let car = record.car else { return [MaintenanceItemRow]() }

            return itemIDs.enumerated().compactMap { index, itemID in
                guard let itemName = nameByID[itemID] else { return nil }
                return MaintenanceItemRow(
                    id: "\(record.id.uuidString)-\(index)-\(itemID.uuidString)",
                    itemID: itemID,
                    itemName: itemName,
                    carName: CarDisplayFormatter.name(car),
                    record: record
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.record.date != rhs.record.date {
                return lhs.record.date > rhs.record.date
            }
            if lhs.record.mileage != rhs.record.mileage {
                return lhs.record.mileage > rhs.record.mileage
            }
            if lhs.itemName != rhs.itemName {
                return lhs.itemName.localizedStandardCompare(rhs.itemName) == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    /// 筛选面板：固定放在列表统计标题上方，按展示模式分别维护各自筛选状态。
    @ViewBuilder
    private func filterPanel(
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

    /// 多选弹窗：统一承接车辆/项目多选，先选择草稿，点击“应用”后再触发筛选。
    @ViewBuilder
    private func selectionSheet(_ target: FilterSelectionSheetTarget) -> some View {
        let options = selectionOptions(for: target.kind)
        let allIDs = Set(options.map(\.id))
        let effectiveSelection = effectiveDraftSelection(target: target, allIDs: allIDs)

        NavigationStack {
            List {
                Section {
                    Button("全选") {
                        hasInteractedWithSelectionDraft = true
                        selectionDraftIDs = allIDs
                    }
                    .disabled(options.isEmpty)

                    Button("清空") {
                        hasInteractedWithSelectionDraft = true
                        selectionDraftIDs = []
                    }
                    .disabled(options.isEmpty)
                }

                Section {
                    if options.isEmpty {
                        Text(target.kind == .car ? "暂无车辆" : "暂无项目")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(options) { option in
                            Button {
                                toggleDraftSelection(
                                    option.id,
                                    target: target,
                                    allIDs: allIDs
                                )
                            } label: {
                                HStack {
                                    Text(option.name)
                                    Spacer()
                                    if effectiveSelection.contains(option.id) {
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
                }
            }
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        selectionSheetTarget = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        applySelectionDraft(target: target, allIDs: allIDs)
                    }
                    .disabled(effectiveSelection.isEmpty)
                }
            }
        }
    }

    /// 按周期可选年份：按年份倒序展示。
    private var cycleYearOptions: [Int] {
        let years = scopedMaintenanceRecords.map { AppDateContext.calendar.component(.year, from: $0.date) }
        return Array(Set(years)).sorted(by: >)
    }

    /// 年份筛选摘要：空值表示不过滤年份。
    private func yearFilterSummary(selectedYear: Int?) -> String {
        guard let selectedYear else { return "全部年份" }
        return "\(selectedYear)年"
    }

    /// 打开多选弹窗：读取当前筛选为草稿，改动在点击“应用”前不会影响列表结果。
    private func presentSelectionSheet(mode: LogDisplayMode, kind: FilterSelectionKind) {
        let current = currentSelectedIDs(mode: mode, kind: kind)
        hasInteractedWithSelectionDraft = false
        selectionDraftIDs = current
        selectionSheetTarget = FilterSelectionSheetTarget(mode: mode, kind: kind)
    }

    /// 当前筛选集合读取：按展示模式和筛选类型定位到对应的状态字段。
    private func currentSelectedIDs(mode: LogDisplayMode, kind: FilterSelectionKind) -> Set<UUID> {
        switch (mode, kind) {
        case (.byDate, .car):
            return cycleFilters.selectedCarIDs
        case (.byDate, .item):
            return cycleFilters.selectedItemIDs
        case (.byItem, .car):
            return itemFilters.selectedCarIDs
        case (.byItem, .item):
            return itemFilters.selectedItemIDs
        }
    }

    /// 可选项列表：车辆/项目复用同一套多选弹窗。
    private func selectionOptions(for kind: FilterSelectionKind) -> [FilterSelectionOption] {
        switch kind {
        case .car:
            return scopedCars.map { car in
                FilterSelectionOption(
                    id: car.id,
                    name: CarDisplayFormatter.name(car)
                )
            }
        case .item:
            return sortedSelectionItemOptions.map { option in
                FilterSelectionOption(
                    id: option.id,
                    name: option.name
                )
            }
        }
    }

    /// 筛选弹窗项目顺序：与“新增/编辑保养”保持一致，避免同类页面排序规则不一致。
    private var sortedSelectionItemOptions: [MaintenanceItemOption] {
        MaintenanceItemCatalog.sortedSelectionOptions(
            options: maintenanceItemOptions,
            records: scopedMaintenanceRecords
        )
    }

    /// 项目自然顺序索引：用于“按周期”项目摘要排序稳定且与项目管理顺序一致。
    private var naturalItemOrderIndexByID: [UUID: Int] {
        let naturalOptions = MaintenanceItemCatalog.naturalSortedOptions(maintenanceItemOptions)
        return Dictionary(uniqueKeysWithValues: naturalOptions.enumerated().map { ($1.id, $0) })
    }

    /// 切换草稿选项：遵循常规多选交互，只做勾选/取消，不做隐式“仅选”跳转。
    private func toggleDraftSelection(
        _ id: UUID,
        target: FilterSelectionSheetTarget,
        allIDs: Set<UUID>
    ) {
        guard allIDs.contains(id) else { return }

        var workingSelection = effectiveDraftSelection(target: target, allIDs: allIDs)
        if workingSelection.contains(id) {
            workingSelection.remove(id)
        } else {
            workingSelection.insert(id)
        }

        hasInteractedWithSelectionDraft = true
        selectionDraftIDs = workingSelection
    }

    /// 当前草稿的“有效选中集合”：解决“全选=空集合”与弹窗勾选显示不一致的问题。
    private func effectiveDraftSelection(
        target: FilterSelectionSheetTarget,
        allIDs: Set<UUID>
    ) -> Set<UUID> {
        guard hasInteractedWithSelectionDraft == false else {
            return selectionDraftIDs
        }
        guard selectionDraftIDs.isEmpty else {
            return selectionDraftIDs
        }

        /// 当当前筛选为“全部”时，弹窗里应显示全勾选，而不是空勾选。
        if currentSelectedIDs(mode: target.mode, kind: target.kind).isEmpty {
            return allIDs
        }
        return selectionDraftIDs
    }

    /// 应用草稿：仅在点击“应用”时回写到筛选状态，并触发列表过滤。
    private func applySelectionDraft(target: FilterSelectionSheetTarget, allIDs: Set<UUID>) {
        var normalized = effectiveDraftSelection(target: target, allIDs: allIDs)
        if normalized.isEmpty {
            return
        }
        if normalized == allIDs {
            normalized = []
        }

        switch (target.mode, target.kind) {
        case (.byDate, .car):
            cycleFilters.selectedCarIDs = normalized
        case (.byDate, .item):
            cycleFilters.selectedItemIDs = normalized
        case (.byItem, .car):
            itemFilters.selectedCarIDs = normalized
        case (.byItem, .item):
            itemFilters.selectedItemIDs = normalized
        }

        selectionSheetTarget = nil
    }

    /// 车辆筛选摘要：用于筛选菜单标签展示。
    private func carFilterSummary(selectedIDs: Set<UUID>) -> String {
        if selectedIDs.isEmpty { return "全部车辆" }
        return "已选\(selectedIDs.count)辆"
    }

    /// 项目筛选摘要：用于筛选菜单标签展示。
    private func itemFilterSummary(selectedIDs: Set<UUID>) -> String {
        if selectedIDs.isEmpty { return "全部项目" }
        return "已选\(selectedIDs.count)项"
    }

    /// 筛选摘要：用于折叠态快速提示当前已生效条件数量。
    private func filterSummary(filters: LogFilterState, mode: LogDisplayMode) -> String {
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

    /// “按周期”过滤规则：车辆多选 + 年份筛选。
    private func matchesCycleFilters(record: MaintenanceRecord, filters: LogFilterState) -> Bool {
        if filters.selectedCarIDs.isEmpty == false {
            guard let carID = record.car?.id, filters.selectedCarIDs.contains(carID) else {
                return false
            }
        }

        if let selectedYear = filters.selectedYear {
            let recordYear = AppDateContext.calendar.component(.year, from: record.date)
            if recordYear != selectedYear {
                return false
            }
        }
        return true
    }

    /// “按周期”项目筛选：只要该周期内任一记录包含选中项目，就展示该周期。
    private func matchesCycleItemFilter(group: MaintenanceDateGroup, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        return group.records.contains { record in
            matchesItemSelection(itemIDsRaw: record.itemIDsRaw, selectedItemIDs: selectedItemIDs)
        }
    }

    /// “按项目”行筛选：空集合代表不过滤，非空时只展示命中的项目行。
    private func matchesItemSelection(rowItemID: UUID, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        return selectedItemIDs.contains(rowItemID)
    }

    /// 字符串项目集合筛选：至少命中一个选中项目才通过。
    private func matchesItemSelection(itemIDsRaw: String, selectedItemIDs: Set<UUID>) -> Bool {
        guard selectedItemIDs.isEmpty == false else { return true }
        let itemIDs = Set(MaintenanceItemCatalog.parseItemIDs(itemIDsRaw))
        guard itemIDs.isEmpty == false else { return false }
        return itemIDs.isDisjoint(with: selectedItemIDs) == false
    }

    /// 日期维度的聚合卡片：单层展示，不使用展开折叠。
    @ViewBuilder
    private func dateGroupRow(_ group: MaintenanceDateGroup) -> some View {
        let rawCarNames = group.records.compactMap(\.car).map(CarDisplayFormatter.name)
        let carNames = Array(Set(rawCarNames))
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
        let minMileage = group.records.map(\.mileage).min()
        let maxMileage = group.records.map(\.mileage).max()

        VStack(alignment: .leading, spacing: 6) {
            Text(DateTextFormatter.shortDate(group.date))
                .font(.headline)

            if group.records.count == 1, let singleRecord = group.records.first {
                if let car = singleRecord.car {
                    Text(CarDisplayFormatter.name(car))
                        .foregroundStyle(.secondary)
                }
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

            if group.records.count == 1, let singleRecord = group.records.first {
                Button("编辑本次保养") {
                    openEditRecord(singleRecord)
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    /// 保养项目维度的行视图，点击可编辑所属保养记录。
    @ViewBuilder
    private func itemRow(_ row: MaintenanceItemRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.itemName)
                .font(.headline)
            Text(row.carName)
                .foregroundStyle(.secondary)
            Text("保养时间：\(DateTextFormatter.shortDate(row.record.date))")
                .foregroundStyle(.secondary)
            Text("里程：\(row.record.mileage) km")
                .foregroundStyle(.secondary)

            Button("编辑本次保养") {
                openEditRecord(row.record, lockedItemID: row.itemID)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    /// 统一打开编辑表单。
    private func openEditRecord(_ record: MaintenanceRecord, lockedItemID: UUID? = nil) {
        editingTarget = MaintenanceRecordEditTarget(record: record, lockedItemID: lockedItemID)
    }

    /// 删除保养记录并立即保存，确保列表与本地数据一致。
    private func deleteRecords(_ records: [MaintenanceRecord]) {
        let recordIDs = Set(records.map(\.id))
        for record in records {
            modelContext.delete(record)
        }
        if let editingTarget, recordIDs.contains(editingTarget.record.id) {
            self.editingTarget = nil
        }
        if let message = modelContext.saveOrLog("删除保养记录") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
        }
    }

    /// “按项目”删除：优先只移除当前项目；仅剩 1 个项目时删除整条记录。
    private func deleteItemRow(_ row: MaintenanceItemRow) {
        let originalItemIDs = MaintenanceItemCatalog.parseItemIDs(row.record.itemIDsRaw)
        guard !originalItemIDs.isEmpty else {
            deleteRecords([row.record])
            return
        }

        if originalItemIDs.count == 1 {
            deleteRecords([row.record])
            return
        }

        var updatedItemIDs = originalItemIDs
        if let firstMatchIndex = updatedItemIDs.firstIndex(of: row.itemID) {
            updatedItemIDs.remove(at: firstMatchIndex)
        } else {
            return
        }

        if updatedItemIDs.isEmpty {
            deleteRecords([row.record])
            return
        }

        row.record.itemIDsRaw = MaintenanceItemCatalog.joinItemIDs(updatedItemIDs)
        MaintenanceItemCatalog.syncCycleAndRelations(for: row.record, in: modelContext)
        if let message = modelContext.saveOrLog("删除项目维度保养记录") {
            saveErrorMessage = message
            isSaveErrorAlertPresented = true
        }
    }

    /// 当前已应用车型ID：若历史值失效，自动回退到首辆车。
    private var appliedCarID: UUID? {
        AppliedCarContext.resolveAppliedCarID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 记录页可见车辆集合：仅保留当前已应用车型。
    private var scopedCars: [Car] {
        guard let appliedCarID else { return [] }
        return cars.filter { $0.id == appliedCarID }
    }

    /// 记录页可见记录集合：按当前已应用车型隔离。
    private var scopedMaintenanceRecords: [MaintenanceRecord] {
        guard let appliedCarID else { return [] }
        return maintenanceRecords.filter { $0.car?.id == appliedCarID }
    }

    /// 同步修正应用车型持久化值，避免删除车辆后指向失效。
    private func syncAppliedCarSelection() {
        appliedCarIDRaw = AppliedCarContext.normalizedRawID(rawID: appliedCarIDRaw, cars: cars)
    }

    /// 车型切换后清理旧筛选，避免残留“已选其他车辆”导致列表误空。
    private func normalizeFilterSelectionsForAppliedCar() {
        let validCarIDs = Set(scopedCars.map(\.id))
        guard validCarIDs.isEmpty == false else {
            cycleFilters.selectedCarIDs = []
            itemFilters.selectedCarIDs = []
            return
        }

        if cycleFilters.selectedCarIDs.isSubset(of: validCarIDs) == false {
            cycleFilters.selectedCarIDs = []
        }
        if itemFilters.selectedCarIDs.isSubset(of: validCarIDs) == false {
            itemFilters.selectedCarIDs = []
        }
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
            return "按周期"
        case .byItem:
            return "按项目"
        }
    }
}

/// 多选弹窗类型：区分“车辆筛选”和“项目筛选”。
private enum FilterSelectionKind: String {
    case car
    case item
}

/// 多选弹窗目标：区分当前是哪个展示模式在配置筛选条件。
private struct FilterSelectionSheetTarget: Identifiable {
    let mode: LogDisplayMode
    let kind: FilterSelectionKind

    var id: String {
        "\(mode.rawValue)-\(kind.rawValue)"
    }

    var title: String {
        switch kind {
        case .car:
            return "选择车辆"
        case .item:
            return "选择保养项目"
        }
    }
}

/// 多选弹窗通用项模型。
private struct FilterSelectionOption: Identifiable {
    let id: UUID
    let name: String
}

/// 记录筛选状态：空集合表示“全选”；按项目模式仅使用项目筛选字段。
private struct LogFilterState {
    var selectedCarIDs: Set<UUID> = []
    var selectedItemIDs: Set<UUID> = []
    var selectedYear: Int?
}

/// “按日期”展示时的聚合模型。
private struct MaintenanceDateGroup: Identifiable {
    let date: Date
    let records: [MaintenanceRecord]
    let itemSummary: String

    var id: Date { date }

    var totalCost: Double {
        records.reduce(0) { $0 + $1.cost }
    }

}

/// “按项目”展示时的中间行模型。
private struct MaintenanceItemRow: Identifiable {
    let id: String
    let itemID: UUID
    let itemName: String
    let carName: String
    let record: MaintenanceRecord
}

/// 编辑目标：区分“整单编辑”与“按项目入口编辑”。
private struct MaintenanceRecordEditTarget: Identifiable {
    let record: MaintenanceRecord
    let lockedItemID: UUID?

    var id: String {
        "\(record.id.uuidString)-\(lockedItemID?.uuidString ?? "all")"
    }
}
