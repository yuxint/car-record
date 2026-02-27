import 'package:uuid/uuid.dart';

/// 车辆数据模型
class Vehicle {
  final String id;
  final String name;
  final String? brand;
  final String? model;
  final String? licensePlate;
  final DateTime? purchaseDate;
  final double? initialMileage;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.name,
    this.brand,
    this.model,
    this.licensePlate,
    this.purchaseDate,
    this.initialMileage,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 创建新车辆
  Vehicle.create({
    required this.name,
    this.brand,
    this.model,
    this.licensePlate,
    this.purchaseDate,
    this.initialMileage,
  })  : id = const Uuid().v4(),
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  /// 从 JSON 数据创建车辆对象
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      licensePlate: json['license_plate'] as String?,
      purchaseDate: json['purchase_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['purchase_date'] as int)
          : null,
      initialMileage: json['initial_mileage'] as double?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  /// 转换为 JSON 数据
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'model': model,
      'license_plate': licensePlate,
      'purchase_date': purchaseDate?.millisecondsSinceEpoch,
      'initial_mileage': initialMileage,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 复制对象并更新部分字段
  Vehicle copyWith({
    String? name,
    String? brand,
    String? model,
    String? licensePlate,
    DateTime? purchaseDate,
    double? initialMileage,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      licensePlate: licensePlate ?? this.licensePlate,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      initialMileage: initialMileage ?? this.initialMileage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 获取车辆显示名称
  String get displayName {
    final buffer = StringBuffer();
    if (brand != null && brand!.isNotEmpty) {
      buffer.write(brand);
      if (model != null && model!.isNotEmpty) {
        buffer.write(' ');
      }
    }
    if (model != null && model!.isNotEmpty) {
      buffer.write(model);
    }
    if (buffer.isEmpty) {
      return name;
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Vehicle{id: $id, name: $name, brand: $brand, model: $model}';
  }
}
