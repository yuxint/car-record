# 按任务最小读取路由

目标：只读取必要上下文，避免每次全量浏览 `docs/agents`。

## 默认读取顺序

1. 先读当前文件（本文件）。
2. 根据改动模块只读对应模块文档（`docs/agents/modules/*.md`）。
3. 仅在触发条件满足时，补读公共文档（见下文“按需补读触发条件”）。

默认上限：除模块文档外，最多再补读 2 份公共文档；超过上限必须有明确风险理由。

## 模块入口

- 改 `AddCar`：`docs/agents/modules/addcar.md`
- 改 `My`：`docs/agents/modules/my.md`
- 改 `MaintenanceReminder`：`docs/agents/modules/maintenance-reminder.md`
- 改 `Records` 或 `AddMaintenanceRecord`：`docs/agents/modules/maintenance-records.md`

## 按需补读触发条件

- 触发“时间相关逻辑”（今天、车龄、进度、日期格式）：
  - 补读 `docs/agents/runtime-contexts.md`
- 触发“当前应用车辆”或“跨 Tab 跳转”：
  - 补读 `docs/agents/runtime-contexts.md`
- 触发“实体字段/唯一约束/删除恢复/导入导出”：
  - 补读 `docs/agents/data-model.md`
- 触发“新增/删除/移动 Swift 文件、资源文件”：
  - 补读 `docs/agents/pbxproj-rules.md`
- 触发“脚本调用或数据备份恢复流程”：
  - 补读 `docs/agents/scripts-reference.md`
- 触发“架构边界、命名、文案、通用约束”：
  - 补读 `docs/agents/business-constraints.md`

## 跨模块影响检查（提交前）

- 是否改了 `Core/*`、`Persistence/*`、`Models/*`。
- 是否改了 `AppliedCarContext`、`AppDateContext`、`AppNavigationContext`。
- 是否改了 `ModelContainerProvider.Schema` 或实体字段。
- 是否改了 `MyDataTransferPayload` 或脚本依赖的数据结构。

若任一项为“是”，需要补读对应公共文档并做回归检查。
