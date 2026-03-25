import SwiftUI
import SwiftData

extension RecordsView {
    @ViewBuilder
    func selectionSheet(_ target: FilterSelectionSheetTarget) -> some View {
        let options = selectionOptions(for: target.kind)
        let allIDs = Set(options.map(\.id))
        let effectiveSelection = effectiveDraftSelection(target: target, allIDs: allIDs)
        let currentSelection = currentSelectedIDs(mode: target.mode, kind: target.kind)
        let normalizedDraftSelection = effectiveSelection == allIDs ? Set<UUID>() : effectiveSelection
        let hasSelectionDraftChanges = normalizedDraftSelection != currentSelection

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
                    Button(AppPopupText.cancel) {
                        selectionSheetTarget = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        applySelectionDraft(target: target, allIDs: allIDs)
                    }
                    .disabled(effectiveSelection.isEmpty || hasSelectionDraftChanges == false)
                }
            }
        }
    }



    /// 切换草稿选项：遵循常规多选交互，只做勾选/取消，不做隐式“仅选”跳转。
    func toggleDraftSelection(
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
    func effectiveDraftSelection(
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
    func applySelectionDraft(target: FilterSelectionSheetTarget, allIDs: Set<UUID>) {
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

}
