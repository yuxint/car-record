import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../config/constants.dart';
import '../models/maintenance_item.dart';

/// 数据库帮助类
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
