import 'package:uuid/uuid.dart';

/// 保养项目数据模型
class MaintenanceItem {
  final String id;
  final String name;
  final bool isDefault;
  final int sortOrder;
  final DateTime createdAt;

  MaintenanceItem({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.sortOrder,
    required this.createdAt,
  });

  /// 创建新保养项目
  MaintenanceItem.create({
    required this.name,
    this.isDefault = false,
    this.sortOrder = 0,
  })  : id = const Uuid().v4(),
        createdAt = DateTime.now();

  /// 创建默认保养项目
  MaintenanceItem.defaultItem({
    required this.name,
    required this.sortOrder,
  })  : id = const Uuid().v4(),
        isDefault = true,
        createdAt = DateTime.now();

  /// 从 JSON 数据创建保养项目对象
  factory MaintenanceItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceItem(
      id: json['id'] as String,
      name: json['name'] as String,
      isDefault: (json['is_default'] as int) == 1,
      sortOrder: json['sort_order'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  /// 转换为 JSON 数据
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// 复制对象并更新部分字段
  MaintenanceItem copyWith({
    String? name,
    bool? isDefault,
    int? sortOrder,
  }) {
    return MaintenanceItem(
      id: id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MaintenanceItem{id: $id, name: $name, isDefault: $isDefault, sortOrder: $sortOrder}';
  }
}
