import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/vehicle.dart';

/// 车辆数据仓库
class VehicleRepository {
  final DatabaseHelper _dbHelper;

  VehicleRepository(this._dbHelper);

  /// 获取所有车辆
  Future<List<Vehicle>> getAllVehicles() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Vehicle.fromJson(maps[i]));
  }

  /// 根据ID获取车辆
  Future<Vehicle?> getVehicleById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Vehicle.fromJson(maps.first);
  }

  /// 插入新车辆
  Future<int> insert(Vehicle vehicle) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'vehicles',
      vehicle.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新车辆
  Future<int> update(Vehicle vehicle) async {
    final db = await _dbHelper.database;
    return await db.update(
      'vehicles',
      vehicle.toJson(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  /// 删除车辆
  Future<int> delete(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'vehicles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取车辆数量
  Future<int> getCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM vehicles');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取第一辆车（用于默认选择）
  Future<Vehicle?> getFirstVehicle() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vehicles',
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Vehicle.fromJson(maps.first);
  }
}
