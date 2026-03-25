import SwiftUI

extension RecordsView {
    @ViewBuilder
    func selectionSheet(_ target: FilterSelectionSheetTarget) -> some View {
        let options = viewModel.selectionOptions(
            for: target.kind,
            cars: cars,
            serviceItemOptions: serviceItemOptions
        )
        let allIDs = Set(options.map(\.id))
        let effectiveSelection = viewModel.effectiveDraftSelection(target: target, allIDs: allIDs)
        let currentSelection = viewModel.currentSelectedIDs(mode: target.mode, kind: target.kind)
        let normalizedDraftSelection = effectiveSelection == allIDs ? Set<UUID>() : effectiveSelection
        let hasSelectionDraftChanges = normalizedDraftSelection != currentSelection

        NavigationStack {
            List {
                Section {
                    Button("全选") {
                        viewModel.hasInteractedWithSelectionDraft = true
                        viewModel.selectionDraftIDs = allIDs
                    }
                    .disabled(options.isEmpty)

                    Button("清空") {
                        viewModel.hasInteractedWithSelectionDraft = true
                        viewModel.selectionDraftIDs = []
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
                                viewModel.toggleDraftSelection(
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
                        viewModel.selectionSheetTarget = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        viewModel.applySelectionDraft(target: target, allIDs: allIDs)
                    }
                    .disabled(effectiveSelection.isEmpty || hasSelectionDraftChanges == false)
                }
            }
        }
    }
}
