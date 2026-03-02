import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../config/theme.dart';
import '../../utils/date_utils.dart' as date_utils;
import '../profile/profile_screen.dart';
import '../maintenance/maintenance_form_screen.dart';

/// 首页 - 展示车辆信息和保养项目进度
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

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
      body: _buildCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: '历史',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '个人',
          ),
        ],
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  /// 构建当前显示的页面
  Widget _buildCurrentScreen() {
    switch (_currentTab) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildHistoryPage();
      case 2:
        return const ProfileScreen();
      default:
        return _buildHomePage();
    }
  }

  /// 构建首页
  Widget _buildHomePage() {
    return Consumer2<VehicleProvider, MaintenanceProvider>(
      builder: (context, vehicleProvider, maintenanceProvider, child) {
        if (vehicleProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!vehicleProvider.hasVehicles) {
          return _buildEmptyVehicleState(context);
        }

        return _buildHomeContent(vehicleProvider, maintenanceProvider);
      },
    );
  }

  /// 构建历史页面
  Widget _buildHistoryPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              '历史记录功能',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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

  /// 构建首页内容
  Widget _buildHomeContent(VehicleProvider vehicleProvider, MaintenanceProvider maintenanceProvider) {
    final vehicle = vehicleProvider.selectedVehicle!;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // 车辆信息部分
          _buildVehicleInfo(vehicle),
          const SizedBox(height: 16),
          
          // 添加保养记录按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MaintenanceFormScreen(vehicle: vehicle),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('添加保养记录'),
            ),
          ),
          const SizedBox(height: 24),
          
          // 保养项目进度部分
          ..._buildMaintenanceItems(),
        ],
      ),
    );
  }

  /// 构建车辆信息
  Widget _buildVehicleInfo(Vehicle vehicle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // 车辆图片
          Image.network(
            'https://img.freepik.com/free-photo/old-vintage-car-isolated-white-background_1340-23818.jpg',
            height: 100,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          
          // 车辆名称和时间
          Text(
            '${vehicle.displayName}, ${vehicle.purchaseDate != null ? date_utils.DateUtils.formatDisplayDate(vehicle.purchaseDate!) : '未设置'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建保养项目
  List<Widget> _buildMaintenanceItems() {
    // 模拟保养项目数据
    final maintenanceItems = [
      {
        'name': '机油、机滤',
        'description': '每天限里限价，有两存就是有法：',
        'progress': 75,
        'icon': Icons.person,
        'image': 'https://img.freepik.com/free-photo/smartphone-with-wooden-case_23-2149426100.jpg'
      },
      {
        'name': '空气滤芯',
        'description': '你的口拾AI机各人。',
        'progress': 65,
        'icon': Icons.book,
        'image': 'https://img.freepik.com/free-photo/portable-radio-isolated-white-background_1368-4042.jpg'
      },
      {
        'name': '空调滤芯',
        'description': '每天限里限价，有两存就是有法：',
        'progress': 85,
        'icon': Icons.circle_outlined,
        'image': 'https://img.freepik.com/free-photo/air-conditioner-filter-cleaning_23-2149370351.jpg'
      },
      {
        'name': '空调滤芯',
        'description': '销音限里限价，有两存就必总有物',
        'progress': 60,
        'icon': Icons.car_repair,
        'image': 'https://img.freepik.com/free-photo/air-conditioner-filter-cleaning_23-2149370351.jpg'
      },
      {
        'name': '变装养油',
        'description': '销音限里限价，有两存就必总有物',
        'progress': 90,
        'icon': Icons.circle_outlined,
        'image': 'https://img.freepik.com/free-photo/smartphone-with-leather-case_23-2149426102.jpg'
      },
    ];

    return maintenanceItems.map((item) {
      final progress = item['progress'] as int;
      final icon = item['icon'] as IconData;
      final imageUrl = item['image'] as String;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 左侧图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                
                // 小图片
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // 保养项目信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['description'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 右侧箭头
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 进度条
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 6,
                  width: MediaQuery.of(context).size.width * 0.8 * (progress / 100),
                  decoration: BoxDecoration(
                    color: progress < 70 ? Colors.green : Colors.blue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}
