# car-record

纯 iOS 客户端项目（SwiftUI + SwiftData），当前采用 **Xcode 手动安装调试**。

## 技术栈

- iOS 17.0+
- SwiftUI
- SwiftData
- 本地持久化存储

## 项目结构

- `ios/CarRecord`: SwiftUI + SwiftData 源码
  - `App`: 应用入口与根导航
  - `Core`: 通用上下文与格式化工具（如 `AppDateContext`、`AppliedCarContext`）
  - `Features`: 按功能拆分（`MaintenanceReminder` / `MaintenanceRecords` / `Garage`）
    - `MaintenanceReminder`: 保养提醒页（Model / View / ViewModel）
    - `MaintenanceRecords`: `AddMaintenanceRecord` / `Records`
    - `Garage`: `AddCar` / `My` / `DataTransfer`
  - `Models`: `Entities` / `MaintenanceItem`
  - `Persistence`: SwiftData 容器与保存封装
- `CarRecord/CarRecord.xcodeproj`: iOS 工程文件
- `scripts`: 模拟器数据备份/恢复、`pbxproj` 文件映射检查脚本

## 本地运行（Xcode）

1. 使用 Xcode 打开 `CarRecord/CarRecord.xcodeproj`
2. 选择 `CarRecord` Scheme 和你的 iPhone 设备
3. 在 `Signing & Capabilities` 中选择你的个人开发者账号
4. 点击 Run（`⌘R`）安装到手机

## 构建说明

```sh
xcodebuild -project CarRecord/CarRecord.xcodeproj -scheme CarRecord -destination 'generic/platform=iOS' build
```

如需验证模拟器编译：

```sh
xcodebuild -project CarRecord/CarRecord.xcodeproj -scheme CarRecord -destination 'generic/platform=iOS Simulator' build
```

## 项目特点

- 应用无网络层，业务数据默认保存在设备本地。
- 根导航固定三大入口：`保养提醒`、`保养记录`、`个人中心`。
- 数据模型包含 `Car`、`MaintenanceRecord`、`MaintenanceRecordItem`、`MaintenanceItemOption`。
- 支持“手动日期”调试模式，涉及“今天/车龄/提醒进度”的逻辑统一走 `AppDateContext.now()`。
- 支持应用内 JSON 备份/恢复，结构由 `MyDataTransferPayload` 定义（`modelProfiles` + `vehicles`）。

## 备份与恢复（可选）

- 导出模拟器数据：

```sh
scripts/sim_data_backup.sh [bundle_id] [backup_root]
```

- 恢复备份目录或 JSON：

```sh
scripts/sim_data_restore.sh <backup_dir_or_json> [bundle_id]
```

## 说明

- 安装与调试以本机 Xcode 手动运行为准
