# 辅助脚本

- `scripts/sim_data_backup.sh [bundle_id] [backup_root]` 会校验 `xcrun` 与 `sqlite3` 命令，默认从 `com.tx.app.CarRecord` 读取正在运行的模拟器容器，再把 `Library/Application Support/default.store{,-wal,-shm}` 拷贝到 `tmp/data-backup/<timestamp>`，并导出 SQL 文本、`row-counts.txt`（包含 `ZCAR/ZMAINTENANCELOG/ZMAINTENANCEITEMOPTION/ZFUELLOG/ZMAINTENANCELOGITEM` 行数）以及 `maintenance-export-v1.json`（后续导入可用的 JSON 结构）。执行结束会打印备份路径并列出目录内容。
- `scripts/sim_data_restore.sh <backup_dir> [bundle_id]` 需要传入包含 `default.store` 的备份目录，默认用 `com.tx.app.CarRecord`。脚本会定位已启动模拟器的容器，清理旧库及 WAL/SHM，再把备份文件覆盖过去，最后 `ls -lah` 并过滤 `default.store*` 以确认回灌结果。
- `scripts/check_pbxproj_mapping.py [--fix] [--project <path>] [--source-root <dir>]` 检查 `ios/CarRecord` 下的 Swift 文件是否都出现在 `CarRecord/CarRecord.xcodeproj/project.pbxproj` 的引用与 Sources phase，`--fix` 会自动新增缺失引用并删除失效映射。默认在仓库根运行，若工程路径或源码根不同可通过 `--project`/`--source-root` 指定，执行前确保 `python3` 可用。
