# 车辆保养记录App - 技术方案文档

## 1. 技术架构概述

### 1.1 技术栈选择
- **框架**: Flutter 3.x
- **语言**: Dart 3.x
- **本地数据库**: sqflite + path_provider + path
- **状态管理**: Provider (轻量级，适合中小型项目)
- **路由管理**: Navigator (标准路由)
- **日期时间处理**: intl
- **ID生成**: uuid

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

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.databaseName);
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDB(String filePath) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String path = join(appDocDir.path, filePath);
    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建数据库表
  Future<void> _createDB(Database db, int version) async {
    // 车辆表
    await db.execute('''
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
    ''');

    // 保养记录表
    await db.execute('''
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
    ''');

    // 保养项目表
    await db.execute('''
      CREATE TABLE maintenance_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // 创建索引
    await db.execute('''
      CREATE INDEX idx_maintenance_records_vehicle_id 
      ON maintenance_records(vehicle_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_maintenance_records_date 
      ON maintenance_records(date DESC)
    ''');

    // 初始化默认保养项目
    await _initDefaultMaintenanceItems(db);
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 处理数据库升级逻辑
    if (oldVersion < newVersion) {
      // 示例：添加新字段
      // await db.execute('ALTER TABLE table_name ADD COLUMN new_column TEXT');
    }
  }

  /// 初始化默认保养项目
  Future<void> _initDefaultMaintenanceItems(Database db) async {
    for (int i = 0; i < AppConstants.defaultMaintenanceItems.length; i++) {
      final item = MaintenanceItem.defaultItem(
        name: AppConstants.defaultMaintenanceItems[i],
        sortOrder: i,
      );
      await db.insert(
        'maintenance_items',
        item.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  /// 删除数据库（仅用于开发调试）
  Future<void> deleteDatabase() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String path = join(appDocDir.path, AppConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
```

---

## 4. 核心功能实现方案

### 4.1 保养记录自动计算逻辑

#### 4.1.1 添加记录时计算间隔
```dart
/// 计算与上一条记录的差值
Future<MaintenanceRecord> _calculateDifferences(MaintenanceRecord record) async {
  final lastRecord = await getLastRecordForVehicle(record.vehicleId, record.date);
  
  if (lastRecord != null) {
    return record.copyWith(
      timeDiffFromLast: record.date.difference(lastRecord.date),
      mileageDiffFromLast: record.mileage - lastRecord.mileage,
    );
  }
  
  return record;
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
class MaintenanceProvider with ChangeNotifier {
  final MaintenanceRepository _repository;
  
  List<MaintenanceRecord> _records = [];
  List<MaintenanceItem> _maintenanceItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  MaintenanceProvider(this._repository);

  List<MaintenanceRecord> get records => _records;
  List<MaintenanceItem> get maintenanceItems => _maintenanceItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasRecords => _records.isNotEmpty;

  /// 获取统计数据
  int get recordCount => _records.length;
  
  double get totalPrice {
    return _records.fold(0.0, (sum, record) => sum + record.price);
  }

  /// 加载某辆车的保养记录
  Future<void> loadRecords(String vehicleId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _records = await _repository.getRecordsByVehicleId(vehicleId);
    } catch (e) {
      _errorMessage = '加载保养记录失败: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载所有保养项目
  Future<void> loadMaintenanceItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _maintenanceItems = await _repository.getAllMaintenanceItems();
    } catch (e) {
      _errorMessage = '加载保养项目失败: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 添加保养记录
  Future<bool> addRecord(MaintenanceRecord record) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.insert(record);
      await loadRecords(record.vehicleId);
      return true;
    } catch (e) {
      _errorMessage = '添加保养记录失败: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 其他方法...
}
```

---

## 5. 路由设计

### 5.1 路由配置 (Navigator)
目前项目使用标准的Navigator进行路由管理，在`main.dart`中通过MaterialApp配置。

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 初始化依赖
    final dbHelper = DatabaseHelper.instance;
    final vehicleRepository = VehicleRepository(dbHelper);
    final maintenanceRepository = MaintenanceRepository(dbHelper);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => VehicleProvider(vehicleRepository),
        ),
        ChangeNotifierProvider(
          create: (context) => MaintenanceProvider(maintenanceRepository),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const RecordListScreen(),
      ),
    );
  }
}
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
