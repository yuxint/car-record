# 车辆保养记录App - 智能代理设计文档

## 项目概览

一个使用Flutter开发的车辆保养记录管理应用，支持多车辆管理、保养记录追踪、保养间隔计算等功能。

## 技术栈

- **框架**：Flutter 3.x
- **语言**：Dart 3.x
- **本地数据库**：sqflite + path_provider + path
- **状态管理**：Provider
- **路由管理**：Navigator
- **日期时间处理**：intl
- **ID生成**：uuid

## 项目架构

### 核心模块

1. **数据模型层** (`lib/models/`)
   - `Vehicle`：车辆数据模型
   - `MaintenanceRecord`：保养记录数据模型
   - `MaintenanceItem`：保养项目数据模型

2. **数据库层** (`lib/database/`)
   - `DatabaseHelper`：数据库操作类，负责创建表结构和初始化默认数据

3. **状态管理层** (`lib/providers/`)
   - `VehicleProvider`：管理车辆数据的状态
   - `MaintenanceProvider`：管理保养记录和保养项目的状态

4. **数据仓库层** (`lib/repositories/`)
   - `VehicleRepository`：车辆数据的持久化操作
   - `MaintenanceRepository`：保养记录和保养项目的持久化操作

5. **视图层** (`lib/views/`)
   - `RecordListScreen`：保养记录列表页面

6. **工具层** (`lib/utils/`)
   - `DateUtils`：日期处理工具

7. **配置层** (`lib/config/`)
   - `constants.dart`：常量定义
   - `theme.dart`：主题配置

## 数据模型设计

### 车辆模型 (`Vehicle`)

| 字段名 | 类型 | 描述 |
|-------|------|------|
| id | String | 车辆唯一标识 |
| name | String | 车辆名称 |
| brand | String? | 品牌 |
| model | String? | 型号 |
| licensePlate | String? | 车牌号 |
| purchaseDate | DateTime? | 购买日期 |
| initialMileage | double? | 初始里程 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### 保养记录模型 (`MaintenanceRecord`)

| 字段名 | 类型 | 描述 |
|-------|------|------|
| id | String | 记录唯一标识 |
| vehicleId | String | 车辆ID |
| date | DateTime | 保养日期 |
| mileage | double | 保养时里程 |
| items | List<String> | 保养项目列表 |
| price | double | 保养费用 |
| notes | String? | 备注 |
| timeDiffFromLast | Duration? | 与上次保养的时间间隔 |
| mileageDiffFromLast | double? | 与上次保养的里程间隔 |
| createdAt | DateTime | 创建时间 |
| updatedAt | DateTime | 更新时间 |

### 保养项目模型 (`MaintenanceItem`)

| 字段名 | 类型 | 描述 |
|-------|------|------|
| id | String | 项目唯一标识 |
| name | String | 项目名称 |
| isDefault | bool | 是否默认项目 |
| sortOrder | int | 排序顺序 |
| createdAt | DateTime | 创建时间 |

## 数据库设计

### 数据表结构

#### 车辆表 (`vehicles`)
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
)
```

#### 保养记录表 (`maintenance_records`)
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
)
```

#### 保养项目表 (`maintenance_items`)
```sql
CREATE TABLE maintenance_items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)
```

### 索引设计
```sql
-- 保养记录按车辆ID索引
CREATE INDEX idx_maintenance_records_vehicle_id 
ON maintenance_records(vehicle_id)

-- 保养记录按日期倒序索引
CREATE INDEX idx_maintenance_records_date 
ON maintenance_records(date DESC)
```

## 核心功能实现

### 1. 多车辆管理

- **添加车辆**：通过`VehicleProvider.addVehicle()`方法添加新车辆
- **编辑车辆**：通过`VehicleProvider.updateVehicle()`方法更新车辆信息
- **删除车辆**：通过`VehicleProvider.deleteVehicle()`方法删除车辆，同时级联删除相关的保养记录
- **选择车辆**：通过`VehicleProvider.selectVehicle()`方法切换当前操作的车辆

### 2. 保养记录管理

- **添加记录**：通过`MaintenanceProvider.addRecord()`方法添加新的保养记录
- **编辑记录**：通过`MaintenanceProvider.updateRecord()`方法更新保养记录
- **删除记录**：通过`MaintenanceProvider.deleteRecord()`方法删除保养记录
- **查看记录**：通过`MaintenanceProvider.loadRecords()`方法加载指定车辆的保养记录

### 3. 保养间隔计算

- **时间间隔**：自动计算与上次保养的时间差，以天、月、年为单位显示
- **里程间隔**：自动计算与上次保养的里程差，以公里为单位显示

### 4. 保养项目管理

- **加载项目**：通过`MaintenanceProvider.loadMaintenanceItems()`方法加载所有保养项目
- **添加项目**：通过`MaintenanceProvider.addMaintenanceItem()`方法添加新的保养项目
- **删除项目**：通过`MaintenanceProvider.deleteMaintenanceItem()`方法删除保养项目

### 5. 数据统计

- **记录数量**：通过`MaintenanceProvider.recordCount`获取保养记录数量
- **总费用**：通过`MaintenanceProvider.totalPrice`计算保养总费用

## 状态管理流程

### 车辆状态管理

1. **初始化**：应用启动时，`VehicleProvider`加载所有车辆数据
2. **选择车辆**：用户选择车辆后，`VehicleProvider`更新选中状态并通知UI更新
3. **添加/编辑/删除**：操作车辆数据后，`VehicleProvider`更新本地状态并通知UI更新

### 保养记录状态管理

1. **初始化**：选择车辆后，`MaintenanceProvider`加载该车辆的保养记录
2. **添加/编辑/删除**：操作保养记录后，`MaintenanceProvider`更新本地状态并通知UI更新
3. **统计数据**：保养记录变化时，自动更新统计数据

## 数据流

```
UI → Provider → Repository → Database → Repository → Provider → UI
```

1. **UI层**：用户界面，负责展示数据和接收用户操作
2. **Provider层**：状态管理，处理业务逻辑，通知UI更新
3. **Repository层**：数据仓库，负责数据持久化操作
4. **Database层**：数据库操作，执行SQL语句

## 应用启动流程

1. **初始化应用**：`main.dart`中初始化`MyApp`组件
2. **初始化依赖**：创建`DatabaseHelper`、`VehicleRepository`和`MaintenanceRepository`实例
3. **配置状态管理**：使用`MultiProvider`配置`VehicleProvider`和`MaintenanceProvider`
4. **启动应用**：设置主题和首页，启动应用
5. **加载数据**：首页加载时，自动加载车辆列表和保养记录

## 核心API

### VehicleProvider

- `loadVehicles()`：加载所有车辆
- `selectVehicle(Vehicle vehicle)`：选择车辆
- `addVehicle(Vehicle vehicle)`：添加车辆
- `updateVehicle(Vehicle vehicle)`：更新车辆
- `deleteVehicle(String id)`：删除车辆

### MaintenanceProvider

- `loadRecords(String vehicleId)`：加载指定车辆的保养记录
- `loadMaintenanceItems()`：加载所有保养项目
- `addRecord(MaintenanceRecord record)`：添加保养记录
- `updateRecord(MaintenanceRecord record)`：更新保养记录
- `deleteRecord(String id, String vehicleId)`：删除保养记录
- `addMaintenanceItem(MaintenanceItem item)`：添加保养项目
- `deleteMaintenanceItem(String id)`：删除保养项目

### VehicleRepository

- `getAllVehicles()`：获取所有车辆
- `getVehicleById(String id)`：根据ID获取车辆
- `insert(Vehicle vehicle)`：插入新车辆
- `update(Vehicle vehicle)`：更新车辆
- `delete(String id)`：删除车辆
- `getCount()`：获取车辆数量
- `getFirstVehicle()`：获取第一辆车

### MaintenanceRepository

- `getRecordsByVehicleId(String vehicleId)`：获取指定车辆的保养记录
- `getAllMaintenanceItems()`：获取所有保养项目
- `insert(MaintenanceRecord record)`：插入新保养记录
- `update(MaintenanceRecord record)`：更新保养记录
- `delete(String id)`：删除保养记录
- `insertMaintenanceItem(MaintenanceItem item)`：插入新保养项目
- `deleteMaintenanceItem(String id)`：删除保养项目

## 未来扩展

### 功能扩展

1. **添加车辆管理页面**：实现车辆的CRUD操作界面
2. **添加保养记录添加/编辑页面**：实现保养记录的详细编辑功能
3. **添加统计分析页面**：提供更详细的保养费用和频率分析
4. **添加设置页面**：允许用户自定义应用设置
5. **实现数据导出功能**：支持将保养记录导出为Excel或PDF
6. **添加通知提醒功能**：根据保养间隔自动提醒用户
7. **优化UI/UX设计**：提升用户体验

### 技术扩展

1. **添加云同步功能**：实现数据的云端备份和同步
2. **添加用户认证**：支持多用户登录
3. **添加第三方集成**：如加油记录、保险记录等
4. **实现离线模式**：支持无网络环境下的正常使用
5. **添加多语言支持**：支持国际化

## 开发规范

- **文件命名**：snake_case (如: maintenance_record.dart)
- **类命名**：PascalCase (如: MaintenanceRecord)
- **变量/方法**：camelCase (如: calculateDifference)
- **常量**：SCREAMING_SNAKE_CASE (如: MAX_MILEAGE)

## 总结

本项目采用Flutter框架开发，实现了一个功能完整的车辆保养记录管理应用。通过分层架构设计，代码结构清晰，易于维护和扩展。应用支持多车辆管理、保养记录追踪、保养间隔计算等核心功能，满足用户对车辆保养管理的基本需求。

未来可以通过扩展功能和技术，进一步提升应用的用户体验和功能完整性，使其成为一个更加全面的车辆管理解决方案。