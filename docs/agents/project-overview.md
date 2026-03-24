# 项目概况

- 本仓库是纯 iOS 客户端项目，技术栈为 `SwiftUI + SwiftData`。
- 当前没有网络层，业务数据默认只保存在设备本地。
- 主工程文件是 `CarRecord/CarRecord.xcodeproj`，主要源码位于 `ios/CarRecord`。
- 当前唯一已确认的 Scheme 是 `CarRecord`。

## 目录说明

- `ios/CarRecord/App`：应用入口与根导航。
- `ios/CarRecord/Core`：共享基础能力（日期上下文、格式化、当前应用车辆、通用弹窗等）。
- `ios/CarRecord/Models`：数据模型与模型工具。
  - `Entities`：SwiftData `@Model` 实体（`Car`、`MaintenanceRecord`、`MaintenanceRecordItem`、`MaintenanceItemOption`）。
  - `MaintenanceItem`：保养项目目录相关能力（序列化、展示、排序、关系同步等）。
- `ios/CarRecord/Persistence`：`ModelContainer` 构建与 `ModelContext` 保存封装。
- `ios/CarRecord/Features/MaintenanceReminder`：保养提醒页。
  - `View`：页面与展示逻辑。
  - `UseCase`：提醒计算等业务规则。
  - `State`：页面展示模型。
- `ios/CarRecord/Features/MaintenanceRecords`：保养记录域。
  - `AddMaintenanceRecord`：新增/编辑记录页面、状态与用例。
  - `Records`：列表、筛选、分组、删除等页面与用例。
- `ios/CarRecord/Features/Garage`：个人中心/车库域。
  - `AddCar`：新增/编辑车辆页面、状态与用例。
  - `My`：个人中心页入口与数据操作用例。
  - `MaintenanceItems`：保养项目管理相关页面。
  - `DataTransfer`：备份/恢复编解码与导入导出支持。
- `scripts`：开发辅助脚本（模拟器数据备份/回灌、`pbxproj` 映射检查与修复）。
- `tmp/data-backup`：脚本生成的本地备份产物，不属于业务源码。

## 代码事实

- 应用入口在 `ios/CarRecord/App/CarRecordApp.swift`，全局注入默认 SwiftData 容器。
- 根 Tab 固定为 3 个入口：`保养提醒`、`保养记录`、`个人中心`。
- UI 文案当前以中文为主，格式化区域使用 `zh_Hans_CN`。
- 项目大量依赖 `@Query`、`@AppStorage` 与页面本地 `@State` 协作，不存在独立的 service/repository 层。
