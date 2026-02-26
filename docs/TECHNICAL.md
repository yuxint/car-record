# 车辆保养记录App - 技术方案文档

## 1. 技术架构概述

### 1.1 技术栈选择
- **框架**: Flutter 3.x
- **语言**: Dart 3.x
- **本地数据库**: sqflite + path_provider
- **状态管理**: Provider (轻量级，适合中小型项目)
- **路由管理**: GoRouter (或 Navigator 2.0)
- **日期时间处理**: intl
- **数据导出**: csv + share_plus

### 1.2 架构模式
采用 **MVVM (Model-View-ViewModel)** 架构模式，结合 Provider 进行状态管理。

---

## 2. 项目结构设计

### 2.1 目录结构
```
lib/
├── main.dart                          # 应用入口
├── config/                            # 配置文件
│   ├── constants.dart                 # 常量定义
│   ├── routes.dart                    # 路由配置
│   └── theme.dart                     # 主题配置
├── models/                            # 数据模型
│   ├── vehicle.dart                   # 车辆模型
│   ├── maintenance_record.dart        # 保养记录模型
│   └── maintenance_item.dart          # 保养项目模型
├── database/                          # 数据库相关
│   ├── database_helper.dart           # 数据库操作类
│   └── tables/                        # 数据表定义
│       ├── vehicle_table.dart
│       ├── maintenance_record_table.dart
│       └── maintenance_item_table.dart
├── providers/                         # 状态管理
│   ├── vehicle_provider.dart          # 车辆状态管理
│   ├── maintenance_provider.dart      # 保养记录状态管理
│   └── settings_provider.dart         # 设置状态管理
├── repositories/                      # 数据仓库层
│   ├── vehicle_repository.dart        # 车辆数据仓库
│   └── maintenance_repository.dart    # 保养记录数据仓库
├── viewmodels/                        # 视图模型层
│   ├── record_list_viewmodel.dart     # 记录列表VM
│   ├── record_form_viewmodel.dart     # 记录表单VM
│   └── statistics_viewmodel.dart      # 统计VM
├── views/                             # 页面视图
│   ├── home/                          # 首页
│   │   └── record_list_screen.dart
│   ├── record/                        # 记录相关
│   │   ├── record_form_screen.dart
│   │   └── record_detail_screen.dart
│   ├── statistics/                    # 统计
│   │   └── statistics_screen.dart
│   ├── vehicle/                       # 车辆管理
│   │   ├── vehicle_list_screen.dart
│   │   └── vehicle_form_screen.dart
│   └── settings/                      # 设置
│       ├── settings_screen.dart
│       └── data_export_screen.dart
├── widgets/                           # 通用组件
│   ├── buttons/
│   ├── inputs/
│   ├── cards/
│   └── dialogs/
├── utils/                             # 工具类
│   ├── date_utils.dart                # 日期工具
│   ├── string_utils.dart              # 字符串工具
│   ├── number_utils.dart              # 数字工具
│   └── csv_exporter.dart              # CSV导出工具
└── services/                          # 服务层
    ├── notification_service.dart      # 通知服务
    └── share_service.dart             # 分享服务
```

---

## 3. 数据库设计

### 3.1 数据表结构

#### 3.1.1 车辆表 (vehicles)
```sql
CREATE TABLE vehicles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  brand TEXT,
  model TEXT,
  license_plate TEXT,
  purchase_date INTEGER,  -- 时间戳
  initial_mileage REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

#### 3.1.2 保养记录表 (maintenance_records)
```sql
CREATE TABLE maintenance_records (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  date INTEGER NOT NULL,         -- 保养日期时间戳
  mileage REAL NOT NULL,          -- 保养时里程
  items TEXT NOT NULL,            -- JSON数组存储保养项目
  price REAL NOT NULL,            -- 保养价格
  notes TEXT,                     -- 备注
  time_diff_from_last INTEGER,    -- 与上次保养时间差(秒)
  mileage_diff_from_last REAL,    -- 与上次保养里程差
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
);
```

#### 3.1.3 保养项目表 (maintenance_items)
```sql
CREATE TABLE maintenance_items (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 1,  -- 0=false, 1=true
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
```

### 3.2 数据库操作设计

#### 3.2.1 数据库帮助类 (DatabaseHelper)
```dart
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  DatabaseHelper._init();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('maintenance.db');
    return _database!;
  }
  
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future _createDB(Database db, int version) async {
    // 创建表
  }
  
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 数据库升级逻辑
  }
}
```

---

## 4. 核心功能实现方案

### 4.1 保养记录自动计算逻辑

#### 4.1.1 添加记录时计算间隔
```dart
Future<void> calculateAndSetDifferences(MaintenanceRecord record) async {
  // 获取同一辆车的上一条记录
  final lastRecord = await _getLastRecordForVehicle(record.vehicleId);
  
  if (lastRecord != null) {
    // 计算时间差
    record.timeDiffFromLast = record.date.difference(lastRecord.date);
    
    // 计算里程差
    record.mileageDiffFromLast = record.mileage - lastRecord.mileage;
  }
}
```

### 4.2 数据导出实现

#### 4.2.1 CSV导出
```dart
class CsvExporter {
  static Future<String> exportMaintenanceRecords(
    List<MaintenanceRecord> records,
  ) async {
    final csvData = <List<String>>[];
    
    // 表头
    csvData.add([
      '日期',
      '里程',
      '保养项目',
      '价格',
      '与上次时间差',
      '与上次里程差',
      '备注',
    ]);
    
    // 数据行
    for (final record in records) {
      csvData.add([
        DateFormat('yyyy-MM-dd').format(record.date),
        record.mileage.toString(),
        record.items.join('; '),
        record.price.toString(),
        _formatDuration(record.timeDiffFromLast),
        record.mileageDiffFromLast?.toString() ?? '',
        record.notes ?? '',
      ]);
    }
    
    return csvData.map((row) => row.join(',')).join('\n');
  }
}
```

### 4.3 状态管理设计

#### 4.3.1 使用 Provider 管理保养记录
```dart
class MaintenanceProvider extends ChangeNotifier {
  final MaintenanceRepository _repository;
  List<MaintenanceRecord> _records = [];
  bool _isLoading = false;
  
  MaintenanceProvider(this._repository);
  
  List<MaintenanceRecord> get records => _records;
  bool get isLoading => _isLoading;
  
  Future<void> loadRecords(String vehicleId) async {
    _isLoading = true;
    notifyListeners();
    
    _records = await _repository.getRecordsByVehicleId(vehicleId);
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> addRecord(MaintenanceRecord record) async {
    await _repository.insert(record);
    await loadRecords(record.vehicleId);
  }
  
  // 其他方法...
}
```

---

## 5. 路由设计

### 5.1 路由配置 (GoRouter)
```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const RecordListScreen(),
    ),
    GoRoute(
      path: '/record/add',
      builder: (context, state) => const RecordFormScreen(),
    ),
    GoRoute(
      path: '/record/edit/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RecordFormScreen(recordId: id);
      },
    ),
    GoRoute(
      path: '/statistics',
      builder: (context, state) => const StatisticsScreen(),
    ),
    GoRoute(
      path: '/vehicles',
      builder: (context, state) => const VehicleListScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
```

---

## 6. 开发规范

### 6.1 命名规范
- **文件命名**: snake_case (如: maintenance_record.dart)
- **类命名**: PascalCase (如: MaintenanceRecord)
- **变量/方法**: camelCase (如: calculateDifference)
- **常量**: SCREAMING_SNAKE_CASE (如: MAX_MILEAGE)

### 6.2 代码风格
- 遵循官方 [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- 使用 `flutter analyze` 检查代码质量
- 适当添加注释，特别是复杂业务逻辑

### 6.3 Git 提交规范
```
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式调整
refactor: 重构
test: 测试相关
chore: 构建/工具相关
```

---

## 7. 测试策略

### 7.1 单元测试
- 数据模型测试
- 工具类测试
- 数据库操作测试

### 7.2 集成测试
- 页面流程测试
- 数据库CRUD集成测试

### 7.3 Widget测试
- 关键组件测试
- 用户交互测试

---

## 8. 发布准备

### 8.1 Android 发布配置
- 配置 app/build.gradle
- 生成签名密钥
- 配置 AndroidManifest.xml

### 8.2 iOS 发布配置
- 配置 Xcode 项目
- 配置 Bundle Identifier
- 配置 App Store Connect

---

## 9. 性能优化建议

### 9.1 数据库优化
- 为常用查询字段添加索引
- 使用批量插入操作
- 适时关闭数据库连接

### 9.2 UI 性能优化
- 使用 const Widget
- 避免不必要的 rebuild
- 长列表使用 ListView.builder
- 图片资源优化

### 9.3 内存优化
- 及时释放资源
- 避免内存泄漏
- 使用弱引用缓存
