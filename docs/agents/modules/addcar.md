# AddCar 模块最小上下文

## 必读

- `ios/CarRecord/Features/Garage/AddCar/View/AddCarView.swift`
- `ios/CarRecord/Features/Garage/AddCar/View/AddCarSheetComponents.swift`
- `ios/CarRecord/Features/Garage/AddCar/ViewModel/AddCarViewModel.swift`
- `ios/CarRecord/Features/Garage/AddCar/Model/AddCarModels.swift`

## 仅当以下改动才读

- 只改 UI：不补读。
- 改默认项目/阈值/`catalogKey`：补读 `docs/agents/data-model.md`，并看 `CoreConfig*.swift`。
- 改日期相关：补读 `docs/agents/runtime-contexts.md`，并看 `AppDateContext.swift`。
- 改删除自定义项目与历史记录限制：看 `MaintenanceRecord.swift`。

## 改完自检 3 条

- 项目名是否被误当主键。
- `ownerCarID` 隔离是否保持。
- 保存是否仍走 `saveOrLog(_:)`。
