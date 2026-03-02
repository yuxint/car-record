import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/maintenance_record.dart';
import '../../models/vehicle.dart';
import '../../providers/maintenance_provider.dart';
import '../../config/theme.dart';

/// 保养记录表单页面 - 用于添加保养记录
class MaintenanceFormScreen extends StatefulWidget {
  final Vehicle vehicle;

  const MaintenanceFormScreen({super.key, required this.vehicle});

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _mileageController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;
  DateTime? _maintenanceDate;
  List<String> _selectedItems = [];
  List<String> _maintenanceItems = [
    '机油',
    '机滤',
    '空滤',
    '空调滤',
    '刹车油',
    '变速箱油',
    '火花塞',
    '刹车片',
    '轮胎',
    '其他',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _mileageController = TextEditingController();
    _priceController = TextEditingController();
    _notesController = TextEditingController();
    _maintenanceDate = DateTime.now();
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加保养记录'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 保养日期
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _maintenanceDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _maintenanceDate = pickedDate;
                    });
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: '保养日期',
                      hintText: '请选择保养日期',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _maintenanceDate != null
                          ? '${_maintenanceDate!.year}-${_maintenanceDate!.month.toString().padLeft(2, '0')}-${_maintenanceDate!.day.toString().padLeft(2, '0')}'
                          : '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请选择保养日期';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 保养里程
              TextFormField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '保养里程',
                  hintText: '请输入保养时的里程(km)',
                  border: OutlineInputBorder(),
                  suffixText: 'km',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入保养里程';
                  }
                  try {
                    double.parse(value);
                  } catch (e) {
                    return '请输入有效的里程数';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 保养项目
              const Text(
                '保养项目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _maintenanceItems.map((item) {
                  return FilterChip(
                    label: Text(item),
                    selected: _selectedItems.contains(item),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedItems.add(item);
                        } else {
                          _selectedItems.remove(item);
                        }
                      });
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryColor,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 保养费用
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '保养费用',
                  hintText: '请输入保养费用(元)',
                  border: OutlineInputBorder(),
                  suffixText: '元',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入保养费用';
                  }
                  try {
                    double.parse(value);
                  } catch (e) {
                    return '请输入有效的费用';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 备注
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '请输入备注信息',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),

              // 保存按钮
              ElevatedButton(
                onPressed: _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('保存记录'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 保存保养记录
  void _saveRecord() {
    if (_formKey.currentState!.validate()) {
      if (_selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少选择一个保养项目')),
        );
        return;
      }

      final record = MaintenanceRecord(
        id: DateTime.now().toString(),
        vehicleId: widget.vehicle.id,
        date: _maintenanceDate!,
        mileage: double.parse(_mileageController.text.trim()),
        items: _selectedItems,
        price: double.parse(_priceController.text.trim()),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final maintenanceProvider = context.read<MaintenanceProvider>();
      maintenanceProvider.addRecord(record);

      Navigator.pop(context);
    }
  }
}
