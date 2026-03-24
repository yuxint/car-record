# 关键业务约束与修改约定

## 关键业务约束

- `Car.id`、`MaintenanceRecord.id`、`MaintenanceRecordItem.id`、`MaintenanceItemOption.id` 均要求唯一。
- `MaintenanceRecord.cycleKey` 用于约束“同车同日唯一”。
- `MaintenanceRecordItem.cycleItemKey` 用于约束“同车同日同项目唯一”。
- 删除车辆会级联删除其保养记录。
- 保养项目通过 `itemIDsRaw` 持久化 UUID 列表，名称展示依赖 `MaintenanceItemOption` 映射，不要把名称当作稳定主键。
- 默认保养项目由 `MaintenanceItemCatalog` 基于品牌派生，当前至少覆盖 `本田`、`日产`。
- 提醒进度按“时间/里程谁先到就采用谁”的规则计算。
- 应用支持“手动日期”调试模式；涉及今天、车龄、提醒进度的逻辑时，优先使用 `AppDateContext.now()`，不要直接写 `Date()`。
- 当前应用车辆通过 `AppliedCarContext` 和 `@AppStorage("applied_car_id")` 维护；涉及车辆选择时要保留失效回退逻辑。

## 修改约定

- 优先保持现有架构，不要无必要引入网络层、状态管理框架或额外抽象层。
- 目录组织遵循 `Feature + UseCase + State + View/Components`，页面文件只承载 UI 编排与事件转发。
- 新增持久化字段或模型时，先检查 `ModelContainerProvider` 的 `Schema` 是否需要同步更新。
- 涉及保存操作时，优先复用 `ModelContext.saveOrLog(_:)`，保持错误提示风格一致。
- 涉及日期展示、金额展示、里程拆分时，优先复用 `ios/CarRecord/Core/Formatters.swift` 与 `ios/CarRecord/Core/AppDateContext.swift`。
- UI 文案、注释与命名以中文语义为主，新增内容应与现有风格一致。
