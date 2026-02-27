import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 保养记录数据模型
class MaintenanceRecord {
  final String id;
  final String vehicleId;
  final DateTime date;
  final double mileage;
  final List<String> items;
  final double price;
  final String? notes;
  final Duration? timeDiffFromLast;
  final double? mileageDiffFromLast;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.mileage,
    required this.items,
    required this.price,
    this.notes,
    this.timeDiffFromLast,
    this.mileageDiffFromLast,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 创建新保养记录
  MaintenanceRecord.create({
    required this.vehicleId,
    required this.date,
    required this.mileage,
    required this.items,
    required this.price,
    this.notes,
    this.timeDiffFromLast,
    this.mileageDiffFromLast,
  })  : id = const Uuid().v4(),
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  /// 从 JSON 数据创建保养记录对象
  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
      mileage: json['mileage'] as double,
      items: (jsonDecode(json['items'] as String) as List<dynamic>)
          .cast<String>(),
      price: json['price'] as double,
      notes: json['notes'] as String?,
      timeDiffFromLast: json['time_diff_from_last'] != null
          ? Duration(seconds: json['time_diff_from_last'] as int)
          : null,
      mileageDiffFromLast: json['mileage_diff_from_last'] as double?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  /// 转换为 JSON 数据
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'date': date.millisecondsSinceEpoch,
      'mileage': mileage,
      'items': jsonEncode(items),
      'price': price,
      'notes': notes,
      'time_diff_from_last': timeDiffFromLast?.inSeconds,
      'mileage_diff_from_last': mileageDiffFromLast,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 复制对象并更新部分字段
  MaintenanceRecord copyWith({
    String? vehicleId,
    DateTime? date,
    double? mileage,
    List<String>? items,
    double? price,
    String? notes,
    Duration? timeDiffFromLast,
    double? mileageDiffFromLast,
    DateTime? updatedAt,
  }) {
    return MaintenanceRecord(
      id: id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      mileage: mileage ?? this.mileage,
      items: items ?? this.items,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      timeDiffFromLast: timeDiffFromLast ?? this.timeDiffFromLast,
      mileageDiffFromLast: mileageDiffFromLast ?? this.mileageDiffFromLast,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 获取格式化的时间差
  String get formattedTimeDiff {
    if (timeDiffFromLast == null) return '-';
    
    final days = timeDiffFromLast!.inDays;
    if (days >= 365) {
      final years = (days / 365).toStringAsFixed(1);
      return '${years}年';
    } else if (days >= 30) {
      final months = (days / 30).toStringAsFixed(1);
      return '${months}个月';
    } else {
      return '${days}天';
    }
  }

  /// 获取格式化的里程差
  String get formattedMileageDiff {
    if (mileageDiffFromLast == null) return '-';
    return '${mileageDiffFromLast!.toStringAsFixed(0)} km';
  }

  /// 获取格式化的价格
  String get formattedPrice {
    return '¥${price.toStringAsFixed(2)}';
  }

  /// 获取保养项目描述
  String get itemsDescription {
    if (items.isEmpty) return '无';
    if (items.length <= 3) return items.join('、');
    return '${items.take(3).join('、')}...';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MaintenanceRecord{id: $id, date: $date, mileage: $mileage, price: $price}';
  }
}
