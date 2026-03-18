# AGENTS.md

## 项目概况

- 本仓库是一个纯 iOS 客户端项目，技术栈为 `SwiftUI + SwiftData`。
- 当前没有网络层，业务数据默认只保存在设备本地。
- 主工程文件是 `CarRecord/CarRecord.xcodeproj`，主要源码位于 `ios/CarRecord`。
- 当前唯一已确认的 Scheme 是 `CarRecord`。

## 目录说明

- `ios/CarRecord/App`: 应用入口与根导航。
- `ios/CarRecord/Models`: 数据模型与模型工具。
  - `Entities`: SwiftData `@Model` 实体（`Car`、`MaintenanceRecord`、`MaintenanceRecordItem`、`MaintenanceItemOption`）。
  - `Catalog`: 保养项目目录工具（序列化、展示、排序、关系同步等）。
- `ios/CarRecord/Persistence`: `ModelContainer` 构建与 `ModelContext` 保存封装。
- `ios/CarRecord/Features/Dashboard`: 概览页。
  - `View`: 页面与展示逻辑。
  - `UseCase`: 提醒计算等业务规则。
  - `State`: 页面展示模型。
- `ios/CarRecord/Features/MaintenanceRecords`: 保养记录域。
  - `AddMaintenanceRecord`: 新增/编辑记录页面、状态与用例。
  - `Records`: 列表、筛选、分组、删除等页面与用例。
- `ios/CarRecord/Features/Garage`: 我的/车库域。
  - `AddCar`: 新增/编辑车辆页面、状态与用例。
  - `My`: 我的页入口与数据操作用例。
  - `MaintenanceItems`: 保养项目管理相关页面。
  - `DataTransfer`: 备份/恢复编解码与导入导出支持。
- `ios/CarRecord/Shared`: 日期、货币、里程、当前应用车辆等共享工具。
- `scripts`: 模拟器数据备份与回灌脚本。
- `tmp/data-backup`: 脚本生成的本地备份产物，不属于业务源码。

## 本地开发

- 用 Xcode 打开 `CarRecord/CarRecord.xcodeproj`。
- 运行前确认 `Signing & Capabilities` 已绑定本机开发者账号。
- README 当前将“Xcode 手动安装调试”视为标准运行方式。
- 命令行构建可优先尝试：

```sh
xcodebuild -project CarRecord/CarRecord.xcodeproj -scheme CarRecord build
```

- **注意**：修改完代码后，由于项目使用 SwiftData，可能会遇到构建问题。如果只是修改了文件名或文件夹名等非核心逻辑，无需强制构建。
- 若要查看模拟器里的本地数据库，可使用：

```sh
scripts/sim_data_backup.sh
scripts/sim_data_restore.sh <backup_dir>
```

## 代码事实

- 应用入口在 `ios/CarRecord/App/CarRecordApp.swift`，全局注入默认 SwiftData 容器。
- 根 Tab 固定为 3 个入口：`概览`、`记录`、`我的`。
- UI 文案当前以中文为主，格式化区域使用 `zh_Hans_CN`。
- 项目大量依赖 `@Query`、`@AppStorage` 和页面本地 `@State` 协作，不存在单独的 service/repository 层。

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
- 目录组织遵循 `Feature + UseCase + State + Components(View)`，页面文件仅承载 UI 编排与事件转发。
- 新增持久化字段或模型时，先检查 `ModelContainerProvider` 的 `Schema` 是否需要同步更新。
- 涉及保存操作时，优先复用 `ModelContext.saveOrLog(_:)`，保持错误提示风格一致。
- 涉及日期展示、金额展示、里程拆分时，优先复用 `Shared/Formatters.swift` 中已有工具。
- 现有页面大量通过选择器和弹窗避免复杂输入；改表单交互前先理解当前 UX 约束。
- UI 文案、注释与命名以中文语义为主，新增内容应与现有风格一致。

## 验证建议

- 修改 SwiftData 约束相关逻辑后，至少手动验证：
  - 新增车辆
  - 新增/编辑保养记录
  - 同车同日重复记录拦截
  - 删除车辆后的级联删除
  - “我的”页备份/恢复
- 修改提醒逻辑后，额外验证：
  - 无历史记录时的默认基准
  - 仅里程提醒
  - 仅时间提醒
  - 同时启用里程和时间提醒
  - 手动日期开启后的表现

## 当前缺口

- 仓库中暂未看到单元测试或 UI 测试目标。
- 暂未看到 CI 工作流配置。
- 如果新增自动化验证，请优先从不依赖真实设备签名的检查开始。
