# car-record

纯 iOS 客户端项目（SwiftUI + SwiftData），当前采用 **Xcode 手动安装调试**。

## 技术栈

- iOS 17.0+
- SwiftUI
- SwiftData
- 本地持久化存储

## 项目结构

- `ios/CarRecord`: SwiftUI + SwiftData 源码
- `CarRecord/CarRecord.xcodeproj`: iOS 工程文件

## 本地运行（Xcode）

1. 使用 Xcode 打开 `CarRecord/CarRecord.xcodeproj`
2. 选择 `CarRecord` Scheme 和你的 iPhone 设备
3. 在 `Signing & Capabilities` 中选择你的个人开发者账号
4. 点击 Run（`⌘R`）安装到手机

## 构建说明

1. 创建一个新的 iOS App 项目（`File -> New -> Project`）
2. 产品名称：`CarRecord`
3. 界面：`SwiftUI`
4. 语言：`Swift`
5. 将 `ios/CarRecord` 中的所有文件添加到应用目标
6. 构建并运行

## 项目特点

- 应用设计上没有网络层
- 所有记录存储在设备上
- 数据存储架构支持未来迁移到 CloudKit 或后端服务，无需修改功能 UI 代码

## 说明

- 安装与调试以本机 Xcode 手动运行为准
