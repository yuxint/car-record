import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';

/// 车辆状态管理
class VehicleProvider with ChangeNotifier {
  final VehicleRepository _repository;
  
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  bool _isLoading = false;
  String? _errorMessage;

  VehicleProvider(this._repository);

  List<Vehicle> get vehicles => _vehicles;
  Vehicle? get selectedVehicle => _selectedVehicle;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasVehicles => _vehicles.isNotEmpty;

  /// 加载所有车辆
  Future<void> loadVehicles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _vehicles = await _repository.getAllVehicles();
      // 如果没有选中的车辆，选择第一辆
      if (_selectedVehicle == null && _vehicles.isNotEmpty) {
        _selectedVehicle = _vehicles.first;
      }
    } catch (e) {
      _errorMessage = '加载车辆列表失败: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 选择车辆
  void selectVehicle(Vehicle vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// 添加车辆
  Future<bool> addVehicle(Vehicle vehicle) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.insert(vehicle);
      await loadVehicles();
      // 如果是第一辆车，自动选中
      if (_vehicles.length == 1) {
        _selectedVehicle = _vehicles.first;
      }
      return true;
    } catch (e) {
      _errorMessage = '添加车辆失败: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 更新车辆
  Future<bool> updateVehicle(Vehicle vehicle) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.update(vehicle);
      await loadVehicles();
      // 如果更新的是当前选中的车辆，更新选中状态
      if (_selectedVehicle?.id == vehicle.id) {
        _selectedVehicle = vehicle;
      }
      return true;
    } catch (e) {
      _errorMessage = '更新车辆失败: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 删除车辆
  Future<bool> deleteVehicle(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.delete(id);
      // 如果删除的是当前选中的车辆，清除选中状态
      if (_selectedVehicle?.id == id) {
        _selectedVehicle = null;
      }
      await loadVehicles();
      // 重新选择第一辆车
      if (_selectedVehicle == null && _vehicles.isNotEmpty) {
        _selectedVehicle = _vehicles.first;
      }
      return true;
    } catch (e) {
      _errorMessage = '删除车辆失败: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
