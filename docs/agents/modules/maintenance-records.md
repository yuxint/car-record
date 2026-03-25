# MaintenanceRecords 模块最小上下文

## 必读

- `ios/CarRecord/Features/MaintenanceRecords/Records/View/RecordsView.swift`
- `ios/CarRecord/Features/MaintenanceRecords/Records/ViewModel/RecordsViewModelQuery.swift`
- `ios/CarRecord/Features/MaintenanceRecords/Records/ViewModel/RecordsViewModelFilterRules.swift`
- `ios/CarRecord/Features/MaintenanceRecords/AddMaintenanceRecord/View/AddMaintenanceRecordView.swift`
- `ios/CarRecord/Features/MaintenanceRecords/AddMaintenanceRecord/ViewModel/AddMaintenanceRecordViewModel.swift`

## 仅当以下改动才读

- 改唯一键/关系同步：补读 `docs/agents/data-model.md`，并看 `MaintenanceRecord*.swift` 与 `SyncUseCase.swift`。
- 改保存后跳转/应用车型：补读 `docs/agents/runtime-contexts.md`。
- 改删除/拆分行为：补读 `docs/agents/business-constraints.md`。

## 改完自检 3 条

- `cycleKey` 与 `cycleItemKey` 是否一致。
- 编辑拆分后是否会重复记录。
- 删除后筛选与分组是否正确。
