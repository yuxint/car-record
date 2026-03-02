import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../config/theme.dart';
import '../vehicle/vehicle_management_screen.dart';

/// 个人页面 - 包含车辆管理入口
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 个人信息卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '用户',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '车辆保养记录',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 功能列表
            Container(
              width: double.infinity,
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
                children: [
                  // 车辆管理
                  ListTile(
                    leading: const Icon(
                      Icons.directions_car,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text('车辆管理'),
                    subtitle: const Text('添加、编辑和删除车辆'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VehicleManagementScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  
                  // 设置
                  ListTile(
                    leading: const Icon(
                      Icons.settings,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text('设置'),
                    subtitle: const Text('应用设置'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // 跳转到设置页面
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('设置功能')),
                      );
                    },
                  ),
                  const Divider(),
                  
                  // 关于
                  ListTile(
                    leading: const Icon(
                      Icons.info,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text('关于'),
                    subtitle: const Text('版本信息'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // 跳转到关于页面
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('关于功能')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
