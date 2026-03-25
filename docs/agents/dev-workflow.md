# 本地开发与测试

## 常用命令入口

- Xcode：打开 `CarRecord/CarRecord.xcodeproj` 后直接运行。
- 真机构建：

```sh
xcodebuild -project CarRecord/CarRecord.xcodeproj -scheme CarRecord -destination 'generic/platform=iOS' build
```

- 模拟器构建：

```sh
xcodebuild -project CarRecord/CarRecord.xcodeproj -scheme CarRecord -destination 'generic/platform=iOS Simulator' build
```

- `pbxproj` 检查：

```sh
scripts/check_pbxproj_mapping.py
```

- `pbxproj` 自动修复：

```sh
scripts/check_pbxproj_mapping.py --fix
```

- 模拟器数据备份：

```sh
scripts/sim_data_backup.sh [bundle_id] [backup_root]
```

- 模拟器数据恢复：

```sh
scripts/sim_data_restore.sh <backup_dir_or_json> [bundle_id]
```

细节见：`docs/agents/scripts-reference.md`。
