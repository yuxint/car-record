# 车辆保养记录App

一个使用Flutter开发的车辆保养记录管理应用，支持多车辆管理、保养记录追踪、保养间隔计算等功能。

## 功能特性

- 🚗 **多车辆管理**：支持添加、编辑、删除多辆车辆
- 📝 **保养记录**：记录每次保养的日期、里程、项目、价格等信息
- 📊 **统计分析**：查看保养费用统计和保养间隔
- 🔄 **自动计算**：自动计算与上次保养的时间和里程间隔
- 📱 **跨平台**：支持iOS、Android、Web等平台

## 技术栈

- **框架**：Flutter 3.x
- **语言**：Dart 3.x
- **本地数据库**：sqflite + path_provider + path
- **状态管理**：Provider
- **路由管理**：Navigator
- **日期时间处理**：intl
- **ID生成**：uuid

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── config/                            # 配置文件
│   ├── constants.dart                 # 常量定义
│   └── theme.dart                     # 主题配置
├── models/                            # 数据模型
│   ├── vehicle.dart                   # 车辆模型
│   ├── maintenance_record.dart        # 保养记录模型
│   └── maintenance_item.dart          # 保养项目模型
├── database/                          # 数据库相关
│   └── database_helper.dart           # 数据库操作类
├── providers/                         # 状态管理
│   ├── vehicle_provider.dart          # 车辆状态管理
│   └── maintenance_provider.dart      # 保养记录状态管理
├── repositories/                      # 数据仓库层
│   ├── vehicle_repository.dart        # 车辆数据仓库
│   └── maintenance_repository.dart    # 保养记录数据仓库
├── views/                             # 页面视图
│   └── home/                          # 首页
│       └── record_list_screen.dart
└── utils/                             # 工具类
    └── date_utils.dart                # 日期工具
```

## 快速开始

### 环境要求

- Flutter 3.11.0 或更高版本
- Dart 3.1.0 或更高版本
- iOS 13.0 或更高版本（iOS平台）
- Android API 21 或更高版本（Android平台）

### 安装与运行

1. **克隆项目**

   ```bash
   git clone <项目地址>
   cd vehicle_maintenance
   ```

2. **安装依赖**

   ```bash
   flutter pub get
   ```

3. **运行项目**

   - **iOS模拟器**
     ```bash
     flutter run -d ios
     ```

   - **Android模拟器**
     ```bash
     flutter run -d android
     ```

   - **Web**
     ```bash
     flutter run -d web
     ```

## 数据库设计

### 数据表

1. **车辆表 (vehicles)**：存储车辆基本信息
2. **保养记录表 (maintenance_records)**：存储保养记录
3. **保养项目表 (maintenance_items)**：存储默认保养项目

### 核心功能

- **保养记录自动计算**：添加保养记录时，自动计算与上次保养的时间和里程间隔
- **数据持久化**：使用SQLite本地数据库存储数据
- **默认保养项目**：内置常用保养项目列表

## 开发规范

- **文件命名**：snake_case (如: maintenance_record.dart)
- **类命名**：PascalCase (如: MaintenanceRecord)
- **变量/方法**：camelCase (如: calculateDifference)
- **常量**：SCREAMING_SNAKE_CASE (如: MAX_MILEAGE)

## 未来计划

- [ ] 添加车辆管理页面
- [ ] 添加保养记录添加/编辑页面
- [ ] 添加统计分析页面
- [ ] 添加设置页面
- [ ] 实现数据导出功能
- [ ] 添加通知提醒功能
- [ ] 优化UI/UX设计

## 贡献

欢迎提交Issue和Pull Request！

## 许可证

本项目采用 MIT 许可证 - 详情请查看 [LICENSE](LICENSE) 文件
