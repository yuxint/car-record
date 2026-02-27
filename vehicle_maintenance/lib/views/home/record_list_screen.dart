import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/maintenance_record.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../config/theme.dart';
import '../../utils/date_utils.dart' as date_utils;

/// 保养记录列表页面
class RecordListScreen extends StatefulWidget {
  const RecordListScreen({super.key});

  @override
  State<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends State<RecordListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final vehicleProvider = context.read<VehicleProvider>();
    final maintenanceProvider = context.read<MaintenanceProvider>();
    
    await vehicleProvider.loadVehicles();
    await maintenanceProvider.loadMaintenanceItems();
    
    if (vehicleProvider.selectedVehicle != null) {
      await maintenanceProvider.loadRecords(vehicleProvider.selectedVehicle!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('保养记录'),
        actions: [
          Consumer<VehicleProvider>(
            builder: (context, vehicleProvider, child) {
              if (vehicleProvider.hasVehicles) {
                return PopupMenuButton<String>(
                  onSelected: (value) {
                    // 处理菜单选择
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'statistics',
                      child: ListTile(
                        leading: Icon(Icons.analytics),
                        title: Text('统计'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'vehicles',
                      child: ListTile(
                        leading: Icon(Icons.directions_car),
                        title: Text('车辆管理'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('设置'),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer2<VehicleProvider, MaintenanceProvider>(
        builder: (context, vehicleProvider, maintenanceProvider, child) {
          if (vehicleProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!vehicleProvider.hasVehicles) {
            return _buildEmptyVehicleState(context);
          }

          if (maintenanceProvider.isLoading && maintenanceProvider.records.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildVehicleSelector(vehicleProvider),
              Expanded(
                child: maintenanceProvider.hasRecords
                    ? _buildRecordList(maintenanceProvider)
                    : _buildEmptyRecordState(context),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<VehicleProvider>(
        builder: (context, vehicleProvider, child) {
          if (!vehicleProvider.hasVehicles) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () {
              // 跳转到添加记录页面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('添加保养记录功能')),
              );
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  /// 构建没有车辆的状态
  Widget _buildEmptyVehicleState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              '还没有添加车辆',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '请先添加一辆车，然后开始记录保养信息',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // 跳转到添加车辆页面
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('添加车辆功能')),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('添加车辆'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建车辆选择器
  Widget _buildVehicleSelector(VehicleProvider vehicleProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前车辆',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vehicleProvider.selectedVehicle?.displayName ?? '未选择',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<Vehicle>(
            icon: const Icon(Icons.arrow_drop_down),
            onSelected: (vehicle) {
              vehicleProvider.selectVehicle(vehicle);
              context.read<MaintenanceProvider>().loadRecords(vehicle.id);
            },
            itemBuilder: (context) {
              return vehicleProvider.vehicles.map((vehicle) {
                return PopupMenuItem<Vehicle>(
                  value: vehicle,
                  child: ListTile(
                    leading: vehicleProvider.selectedVehicle?.id == vehicle.id
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                        : const Icon(Icons.radio_button_unchecked),
                    title: Text(vehicle.displayName),
                    subtitle: vehicle.licensePlate != null
                        ? Text(vehicle.licensePlate!)
                        : null,
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
    );
  }

  /// 构建记录列表
  Widget _buildRecordList(MaintenanceProvider maintenanceProvider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: maintenanceProvider.records.length,
      itemBuilder: (context, index) {
        final record = maintenanceProvider.records[index];
        return _buildRecordCard(record, index);
      },
    );
  }

  /// 构建记录卡片
  Widget _buildRecordCard(MaintenanceRecord record, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          // 查看记录详情
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      date_utils.DateUtils.formatDisplayDate(record.date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    record.formattedPrice,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.speed, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${record.mileage.toStringAsFixed(0)} km',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 24),
                  if (record.timeDiffFromLast != null) ...[
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      record.formattedTimeDiff,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                  const SizedBox(width: 24),
                  if (record.mileageDiffFromLast != null) ...[
                    Icon(Icons.route, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      record.formattedMileageDiff,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.build, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.itemsDescription,
                      style: TextStyle(color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.notes!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建没有记录的状态
  Widget _buildEmptyRecordState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              '还没有保养记录',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '点击右下角的 + 按钮添加第一条保养记录',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
