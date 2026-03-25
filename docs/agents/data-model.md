# 数据模型与持久化约束

## 关键实体（最小字段）

- `Car`：`id`、`disabledItemIDsRaw`、`serviceRecords(cascade)`
- `MaintenanceRecord`：`id`、`cycleKey(unique)`、`itemIDsRaw`、`itemRelations(cascade)`
- `MaintenanceRecordItem`：`id`、`cycleItemKey(unique)`、`itemID`
- `MaintenanceItemOption`：`id`、`ownerCarID`、`catalogKey`

## 不可破坏规则

- “同车同日唯一”由 `MaintenanceRecord.cycleKey` 保证。
- “同车同日同项目唯一”由 `MaintenanceRecordItem.cycleItemKey` 保证。
- `itemIDsRaw` 持久化的是 UUID 列表，不是项目名。
- `MaintenanceItemOption` 通过 `ownerCarID` 做车辆隔离。
- 新增实体或新增持久化模型字段时，要同步检查 `ModelContainerProvider` 中 `Schema`。

## 删除/恢复边界

- 删除车辆：级联删除该车 `MaintenanceRecord`；同时删除 `ownerCarID` 命中的 `MaintenanceItemOption`。
- 清空业务数据：清理车辆、项目、记录三类核心业务数据。
- 数据恢复脚本优先使用 JSON 结构化恢复，兜底才做整库覆盖。
