# 本地开发与测试

## 本地开发

- 用 Xcode 打开 `CarRecord/CarRecord.xcodeproj`。
- 运行前确认 `Signing & Capabilities` 已绑定本机开发者账号。
- 命令行构建可优先尝试：

```sh
xcodebuild -project CarRecord/CarRecord.xcodeproj -scheme CarRecord build
```

- 若要查看模拟器里的本地数据库并生成可导入快照，先启动模拟器并安装 CarRecord，再运行：

```sh
scripts/sim_data_backup.sh [bundle_id] [backup_root]
```

默认 `bundle_id=com.tx.app.CarRecord`、`backup_root=tmp/data-backup`。

- 想把快照回灌到已运行模拟器，使用：

```sh
scripts/sim_data_restore.sh <backup_dir> [bundle_id]
```

## 测试流程

- `tmp/test/车辆管理手测清单.md` 包含车辆管理相关的模拟器验收用例；执行前填写执行人/日期/版本/设备，按状态框打勾并在失败/阻塞项写明实际结果、截图编号与复现步骤。
- 将测试结论写入文档末尾的"测试结论"字段以便后续回归参考。
