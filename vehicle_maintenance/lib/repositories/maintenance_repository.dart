import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/maintenance_record.dart';
import '../models/maintenance_item.dart';

/// 保养记录数据仓库
class MaintenanceRepository {
  final DatabaseHelper _dbHelper;

  MaintenanceRepository(this._dbHelper);

  /// 获取某辆车的所有保养记录
  Future<List<MaintenanceRecord>> getRecordsByVehicleId(String vehicleId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'maintenance_records',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => MaintenanceRecord.fromJson(maps[i]));
  }

  /// 根据ID获取保养记录
  Future<MaintenanceRecord?> getRecordById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'maintenance_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return MaintenanceRecord.fromJson(maps.first);
  }

  /// 获取某辆车的上一条保养记录
  Future<MaintenanceRecord?> getLastRecordForVehicle(String vehicleId, DateTime beforeDate) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'maintenance_records',
      where: 'vehicle_id = ? AND date < ?',
      whereArgs: [vehicleId, beforeDate.millisecondsSinceEpoch],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MaintenanceRecord.fromJson(maps.first);
  }

  /// 插入新保养记录
  Future<int> insert(MaintenanceRecord record) async {
    final db = await _dbHelper.database;
    // 先计算与上一条记录的差值
    final recordWithDiff = await _calculateDifferences(record);
    return await db.insert(
      'maintenance_records',
      recordWithDiff.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新保养记录
  Future<int> update(MaintenanceRecord record) async {
    final db = await _dbHelper.database;
    // 重新计算与上一条记录的差值
    final recordWithDiff = await _calculateDifferences(record);
    return await db.update(
      'maintenance_records',
      recordWithDiff.toJson(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// 删除保养记录
  Future<int> delete(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'maintenance_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除某辆车的所有保养记录
  Future<int> deleteByVehicleId(String vehicleId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'maintenance_records',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
    );
  }

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

  /// 获取保养记录总数
  Future<int> getCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM maintenance_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取某辆车的保养记录数
  Future<int> getCountByVehicleId(String vehicleId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM maintenance_records WHERE vehicle_id = ?',
      [vehicleId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取某辆车的总保养费用
  Future<double> getTotalPriceByVehicleId(String vehicleId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(price) as total FROM maintenance_records WHERE vehicle_id = ?',
      [vehicleId],
    );
    final total = result.first['total'] as num?;
    return total?.toDouble() ?? 0.0;
  }

  // ========== 保养项目相关 ==========

  /// 获取所有保养项目
  Future<List<MaintenanceItem>> getAllMaintenanceItems() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'maintenance_items',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return List.generate(maps.length, (i) => MaintenanceItem.fromJson(maps[i]));
  }

  /// 插入保养项目
  Future<int> insertMaintenanceItem(MaintenanceItem item) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'maintenance_items',
      item.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除保养项目
  Future<int> deleteMaintenanceItem(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'maintenance_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
