# 项目概况

- 纯 iOS 客户端（`SwiftUI + SwiftData`），无网络层。
- 工程文件：`CarRecord/CarRecord.xcodeproj`，Scheme：`CarRecord`。
- 主要源码：`ios/CarRecord`。
- 根 Tab：`保养提醒`、`保养记录`、`个人中心`。
- 状态管理：`@Query` + `@AppStorage` + 本地状态。

## 仓库关键目录

- `ios/CarRecord/App`：应用入口与根导航。
- `ios/CarRecord/Features`：业务模块（AddCar / My / Reminder / Records）。
- `ios/CarRecord/Core`：公共上下文与格式化。
- `ios/CarRecord/Models`：实体与保养项目工具。
- `ios/CarRecord/Persistence`：容器与保存封装。
- `scripts`：备份恢复与 `pbxproj` 检查脚本。

## 下一步

- 先读：`docs/agents/context-routing.md`
