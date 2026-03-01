/// 应用常量配置
class AppConstants {
  // 数据库配置
  static const String databaseName = 'maintenance.db';
  static const int databaseVersion = 1;

  // 日期格式
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';

  // 默认保养项目
  static const List<String> defaultMaintenanceItems = [
    '机油更换',
    '机滤更换',
    '空滤更换',
    '空调滤更换',
    '火花塞更换',
    '刹车油更换',
    '变速箱油更换',
    '轮胎更换',
    '轮胎换位',
    '四轮定位',
    '刹车片更换',
    '刹车盘更换',
    '蓄电池更换',
    '防冻液更换',
    '雨刮片更换',
  ];

  // 数值范围
  static const double minMileage = 0;
  static const double maxMileage = 9999999;
  static const double minPrice = 0;
  static const double maxPrice = 999999;

  // 页面路由
  static const String routeHome = '/';
  static const String routeRecordAdd = '/record/add';
  static const String routeRecordEdit = '/record/edit';
  static const String routeStatistics = '/statistics';
  static const String routeVehicles = '/vehicles';
  static const String routeVehicleAdd = '/vehicle/add';
  static const String routeVehicleEdit = '/vehicle/edit';
  static const String routeSettings = '/settings';

  // 其他
  static const String appName = '车辆保养记录';
  static const String appVersion = '1.0.0';
}
