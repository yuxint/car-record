import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../config/theme.dart';

/// 车辆表单页面 - 用于添加和编辑车辆
class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const VehicleFormScreen({super.key, this.vehicle});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _licensePlateController;
  late TextEditingController _initialMileageController;
  DateTime? _purchaseDate;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.vehicle?.name ?? '');
    _brandController = TextEditingController(text: widget.vehicle?.brand ?? '');
    _modelController = TextEditingController(text: widget.vehicle?.model ?? '');
    _licensePlateController = TextEditingController(text: widget.vehicle?.licensePlate ?? '');
    _initialMileageController = TextEditingController(
      text: widget.vehicle?.initialMileage?.toString() ?? '',
    );
    _purchaseDate = widget.vehicle?.purchaseDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _licensePlateController.dispose();
    _initialMileageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? '添加车辆' : '编辑车辆'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 车辆名称
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '车辆名称',
                  hintText: '请输入车辆名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入车辆名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 品牌
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: '品牌',
                  hintText: '请输入车辆品牌',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 型号
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: '型号',
                  hintText: '请输入车辆型号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 车牌号
              TextFormField(
                controller: _licensePlateController,
                decoration: const InputDecoration(
                  labelText: '车牌号',
                  hintText: '请输入车牌号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 购买日期
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _purchaseDate = pickedDate;
                    });
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: '购买日期',
                      hintText: '请选择购买日期',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _purchaseDate != null
                          ? '${_purchaseDate!.year}-${_purchaseDate!.month.toString().padLeft(2, '0')}-${_purchaseDate!.day.toString().padLeft(2, '0')}'
                          : '',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 初始里程
              TextFormField(
                controller: _initialMileageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '初始里程',
                  hintText: '请输入初始里程(km)',
                  border: OutlineInputBorder(),
                  suffixText: 'km',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    try {
                      double.parse(value);
                    } catch (e) {
                      return '请输入有效的里程数';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // 保存按钮
              ElevatedButton(
                onPressed: _saveVehicle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(widget.vehicle == null ? '添加车辆' : '保存修改'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 保存车辆信息
  void _saveVehicle() {
    if (_formKey.currentState!.validate()) {
      final vehicle = Vehicle(
        id: widget.vehicle?.id ?? DateTime.now().toString(),
        name: _nameController.text.trim(),
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
        licensePlate: _licensePlateController.text.trim().isEmpty ? null : _licensePlateController.text.trim(),
        purchaseDate: _purchaseDate,
        initialMileage: _initialMileageController.text.trim().isEmpty
            ? null
            : double.parse(_initialMileageController.text.trim()),
        createdAt: widget.vehicle?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final vehicleProvider = context.read<VehicleProvider>();
      if (widget.vehicle == null) {
        vehicleProvider.addVehicle(vehicle);
      } else {
        vehicleProvider.updateVehicle(vehicle);
      }

      Navigator.pop(context);
    }
  }
}
