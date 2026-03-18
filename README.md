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
  - `Features`: 按功能拆分（`Dashboard` / `MaintenanceRecords` / `Garage`）
    - `Dashboard`: `View` / `UseCase` / `State`
    - `MaintenanceRecords`: `AddMaintenanceRecord` / `Records`
    - `Garage`: `AddCar` / `My` / `MaintenanceItems` / `DataTransfer`
  - `Models`: `Entities` / `Catalog`
  - `Persistence`: SwiftData 容器与保存封装
  - `Shared`: 公共格式化与上下文工具
- `CarRecord/CarRecord.xcodeproj`: iOS 工程文件

## 本地运行（Xcode）

1. 使用 Xcode 打开 `CarRecord/CarRecord.xcodeproj`
2. 选择 `CarRecord` Scheme 和你的 iPhone 设备
3. 在 `Signing & Capabilities` 中选择你的个人开发者账号
4. 点击 Run（`⌘R`）安装到手机

## 构建说明

```sh
xcodebuild -project CarRecord/CarRecord.xcodeproj -scheme CarRecord build
```

## 项目特点

- 应用设计上没有网络层
- 所有记录存储在设备上
- 数据存储架构支持未来迁移到 CloudKit 或后端服务，无需修改功能 UI 代码

## 说明

- 安装与调试以本机 Xcode 手动运行为准
