import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'database/database_helper.dart';
import 'providers/vehicle_provider.dart';
import 'providers/maintenance_provider.dart';
import 'repositories/vehicle_repository.dart';
import 'repositories/maintenance_repository.dart';
import 'views/home/record_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 初始化依赖
    final dbHelper = DatabaseHelper.instance;
    final vehicleRepository = VehicleRepository(dbHelper);
    final maintenanceRepository = MaintenanceRepository(dbHelper);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => VehicleProvider(vehicleRepository),
        ),
        ChangeNotifierProvider(
          create: (context) => MaintenanceProvider(maintenanceRepository),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const RecordListScreen(),
      ),
    );
  }
}
