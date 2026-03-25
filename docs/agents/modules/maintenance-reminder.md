# MaintenanceReminder 模块最小上下文

## 必读

- `ios/CarRecord/Features/MaintenanceReminder/View/MaintenanceReminderView.swift`
- `ios/CarRecord/Features/MaintenanceReminder/ViewModel/MaintenanceReminderViewModel.swift`
- `ios/CarRecord/Features/MaintenanceReminder/ViewModel/MaintenanceReminderRules.swift`
- `ios/CarRecord/Features/MaintenanceReminder/Model/MaintenanceReminderModels.swift`

## 仅当以下改动才读

- 改“今天/日期换算”：补读 `docs/agents/runtime-contexts.md`，并看 `AppDateContext.swift`。
- 改阈值或默认项目规则：补读 `docs/agents/data-model.md`，并看 `CoreConfig*.swift`。
- 改应用车型筛选：看 `AppliedCarContext.swift`。

## 改完自检 3 条

- 进度规则是否仍为“时间/里程谁先到”。
- 是否仍统一走时间上下文。
- 应用车型失效回退是否保留。
