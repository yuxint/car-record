# 车辆保养记录App - 知识库

## 项目概述

这是一个使用Flutter开发的车辆保养记录应用，帮助用户管理和追踪车辆保养历史，数据完全存储在本地，无需联网。

### 核心功能
- 保养记录管理（添加、编辑、删除记录）
- 多车辆管理
- 保养间隔自动计算
- 本地数据存储
- 支持深色模式

## 技术栈

- **框架**: Flutter 3.x
- **语言**: Dart 3.x
- **本地数据库**: sqflite + path_provider
- **状态管理**: Provider
- **依赖包**:
  - cupertino_icons: ^1.0.8
  - provider: ^6.1.1
  - uuid: ^4.4.0
  - intl: ^0.19.0
  - sqflite: ^2.3.3+1
  - path_provider: ^2.1.4
  - path: ^1.9.0

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
│       └── record_list_screen.dart    # 记录列表页面
└── utils/                             # 工具类
    └── date_utils.dart                # 日期工具
```

## 数据模型

### 1. 车辆 (Vehicle)

**属性**:
- id: String (UUID)
- name: String (车辆名称)
- brand: String? (品牌)
- model: String? (型号)
- licensePlate: String? (车牌号)
- purchaseDate: DateTime? (购买日期)
- initialMileage: double? (初始里程)
- createdAt: DateTime (创建时间)
- updatedAt: DateTime (更新时间)

**主要方法**:
- create(): 创建新车辆
- fromJson(): 从JSON创建车辆对象
- toJson(): 转换为JSON
- copyWith(): 复制并更新字段
- displayName: 获取显示名称

### 2. 保养记录 (MaintenanceRecord)

**属性**:
- id: String (UUID)
- vehicleId: String (关联车辆ID)
- date: DateTime (保养日期)
- mileage: double (保养时里程)
- items: List<String> (保养项目)
- price: double (保养价格)
- notes: String? (备注)
- timeDiffFromLast: Duration? (与上次保养时间差)
- mileageDiffFromLast: double? (与上次保养里程差)
- createdAt: DateTime (创建时间)
- updatedAt: DateTime (更新时间)

**主要方法**:
- create(): 创建新保养记录
- fromJson(): 从JSON创建记录对象
- toJson(): 转换为JSON
- copyWith(): 复制并更新字段
- formattedTimeDiff: 格式化时间差
- formattedMileageDiff: 格式化里程差
- formattedPrice: 格式化价格
- itemsDescription: 保养项目描述

### 3. 保养项目 (MaintenanceItem)

**属性**:
- id: String (UUID)
- name: String (项目名称)
- isDefault: bool (是否为默认项目)
- sortOrder: int (排序)
- createdAt: DateTime (创建时间)

**主要方法**:
- create(): 创建新保养项目
- defaultItem(): 创建默认保养项目
- fromJson(): 从JSON创建项目对象
- toJson(): 转换为JSON
- copyWith(): 复制并更新字段

## 数据库结构

### 1. 车辆表 (vehicles)

```sql
CREATE TABLE vehicles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  brand TEXT,
  model TEXT,
  license_plate TEXT,
  purchase_date INTEGER,
  initial_mileage REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### 2. 保养记录表 (maintenance_records)

```sql
CREATE TABLE maintenance_records (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  date INTEGER NOT NULL,
  mileage REAL NOT NULL,
  items TEXT NOT NULL,
  price REAL NOT NULL,
  notes TEXT,
  time_diff_from_last INTEGER,
  mileage_diff_from_last REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
);
```

### 3. 保养项目表 (maintenance_items)

```sql
CREATE TABLE maintenance_items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
```

## 应用配置

### 常量配置 (AppConstants)

- **数据库配置**:
  - databaseName: 'maintenance.db'
  - databaseVersion: 1

- **日期格式**:
  - dateFormat: 'yyyy-MM-dd'
  - dateTimeFormat: 'yyyy-MM-dd HH:mm:ss'

- **默认保养项目**:
  - 机油更换、机滤更换、空滤更换、空调滤更换、火花塞更换等

- **数值范围**:
  - minMileage: 0
  - maxMileage: 9999999
  - minPrice: 0
  - maxPrice: 999999

- **应用信息**:
  - appName: '车辆保养记录'
  - appVersion: '1.0.0'

### 主题配置 (AppTheme)

- 支持浅色主题和深色主题
- 主题模式跟随系统设置

## 核心功能实现

### 1. 保养记录管理

- **添加保养记录**:
  - 输入保养日期、里程、项目、价格、备注
  - 自动计算与上次保养的时间差和里程差

- **编辑保养记录**:
  - 修改已有记录的所有字段

- **删除保养记录**:
  - 支持删除单条记录
  - 有确认提示

### 2. 车辆管理

- **添加车辆**:
  - 输入车辆名称、品牌、型号、车牌号、购买日期、初始里程

- **编辑车辆**:
  - 修改已有车辆的信息

- **删除车辆**:
  - 支持删除车辆，同时删除关联的保养记录

### 3. 数据存储

- 使用sqflite进行本地数据存储
- 数据库文件存储在应用文档目录
- 支持数据库版本升级
- 初始化时添加默认保养项目

## 开发规范

### 命名规范
- **文件命名**: snake_case (如: maintenance_record.dart)
- **类命名**: PascalCase (如: MaintenanceRecord)
- **变量/方法**: camelCase (如: calculateDifference)
- **常量**: SCREAMING_SNAKE_CASE (如: MAX_MILEAGE)

### 代码风格
- 遵循官方 Dart Style Guide
- 使用 flutter analyze 检查代码质量
- 适当添加注释，特别是复杂业务逻辑

### Git 提交规范
```
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式调整
refactor: 重构
test: 测试相关
chore: 构建/工具相关
```

## 发布准备

### Android 发布配置
- 配置 app/build.gradle
- 生成签名密钥
- 配置 AndroidManifest.xml

### iOS 发布配置
- 配置 Xcode 项目
- 配置 Bundle Identifier
- 配置 App Store Connect

## 性能优化建议

### 数据库优化
- 为常用查询字段添加索引
- 使用批量插入操作
- 适时关闭数据库连接

### UI 性能优化
- 使用 const Widget
- 避免不必要的 rebuild
- 长列表使用 ListView.builder
- 图片资源优化

### 内存优化
- 及时释放资源
- 避免内存泄漏
- 使用弱引用缓存

## 后续迭代规划

### v1.1 规划
- [ ] 保养提醒功能
- [ ] 数据可视化图表
- [ ] 保养费用趋势分析

### v1.2 规划
- [ ] 保养照片上传
- [ ] 票据管理
- [ ] 保养小贴士

### v2.0 规划
- [ ] 云端同步（可选）
- [ ] 多设备数据同步
- [ ] 保养预约功能