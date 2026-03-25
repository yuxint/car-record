# 辅助脚本

- `scripts/sim_data_backup.sh [bundle_id] [backup_root]`
  - 依赖：`xcrun`、`sqlite3`、`python3`。
  - 默认从 `com.tx.app.CarRecord` 的已启动模拟器容器读取 `Library/Application Support/default.store`。
  - 产物输出到 `tmp/data-backup/<timestamp>`（可通过参数覆盖），包含：
    - `default.store` / `default.store-wal` / `default.store-shm`（存在才拷贝）
    - `default.store.sql`（SQLite dump）
    - `row-counts.txt`（行数快照，含 `ZCAR/ZMAINTENANCELOG/ZMAINTENANCEITEMOPTION/ZFUELLOG/ZMAINTENANCELOGITEM`）
    - `maintenance-export.json`（与应用 `MyDataTransferPayload` 兼容，根节点 `modelProfiles` + `vehicles`）
- `scripts/sim_data_restore.sh <backup_dir_or_json> [bundle_id]`
  - 依赖：`xcrun`、`python3`。
  - 恢复优先级：
    - 若传入目录内包含 `maintenance-export.json`，或直接传入 JSON 文件：执行结构化恢复。
    - 否则若仅有 `default.store`：执行整库覆盖回灌（会先清理目标容器中的 `default.store*`）。
  - JSON 恢复会按脚本内约束校验并重建车辆/项目/记录数据，同时写回 `cycleKey` 与 `cycleItemKey` 对应字段（底层表字段）。
- `scripts/check_pbxproj_mapping.py [--fix] [--project <path>] [--source-root <dir>]`
  - 检查 `ios/CarRecord` 下 Swift 文件是否都映射到 `CarRecord/CarRecord.xcodeproj/project.pbxproj` 的引用与 Sources phase。
  - `--fix` 会自动新增缺失引用并移除无效映射。
  - 默认在仓库根运行；非默认路径可通过 `--project`/`--source-root` 指定。
