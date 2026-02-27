import 'package:flutter/foundation.dart';
import '../models/maintenance_record.dart';
import '../models/maintenance_item.dart';
import '../repositories/maintenance_repository.dart';

/// 保养记录状态管理
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

  /// 更新保养记录
  Future<bool> updateRecord(MaintenanceRecord record) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.update(record);
      await loadRecords(record.vehicleId);
      return true;
    } catch (e) {
      _errorMessage = '更新保养记录失败: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 删除保养记录
  Future<bool> deleteRecord(String id, String vehicleId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.delete(id);
      await loadRecords(vehicleId);
      return true;
    } catch (e) {
      _errorMessage = '删除保养记录失败: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 添加保养项目
  Future<bool> addMaintenanceItem(MaintenanceItem item) async {
    try {
      await _repository.insertMaintenanceItem(item);
      await loadMaintenanceItems();
      return true;
    } catch (e) {
      _errorMessage = '添加保养项目失败: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }

  /// 删除保养项目
  Future<bool> deleteMaintenanceItem(String id) async {
    try {
      await _repository.deleteMaintenanceItem(id);
      await loadMaintenanceItems();
      return true;
    } catch (e) {
      _errorMessage = '删除保养项目失败: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
