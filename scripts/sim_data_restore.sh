#!/usr/bin/env bash
set -euo pipefail

# 将备份目录中的 default.store 回灌到已启动模拟器的 CarRecord 容器。
# 用法：scripts/sim_data_restore.sh <备份目录> [bundle_id]
BACKUP_DIR="${1:-}"
BUNDLE_ID="${2:-com.tx.app.CarRecord}"

if [[ -z "$BACKUP_DIR" ]]; then
  echo "请传入备份目录，例如：scripts/sim_data_restore.sh tmp/data-backup/20260316-142114" >&2
  exit 1
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "备份目录不存在：$BACKUP_DIR" >&2
  exit 1
fi

if [[ ! -f "$BACKUP_DIR/default.store" ]]; then
  echo "备份目录缺少 default.store：$BACKUP_DIR/default.store" >&2
  exit 1
fi

DATA_CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null || true)"
if [[ -z "$DATA_CONTAINER" ]]; then
  echo "未找到已启动模拟器中的应用容器：$BUNDLE_ID" >&2
  echo "请先启动模拟器并确保应用已安装。" >&2
  exit 1
fi

DB_DIR="$DATA_CONTAINER/Library/Application Support"
mkdir -p "$DB_DIR"

# 先清理旧库，再覆盖回灌，避免 WAL/SHM 与主库不匹配。
rm -f "$DB_DIR/default.store" "$DB_DIR/default.store-wal" "$DB_DIR/default.store-shm"
cp "$BACKUP_DIR/default.store" "$DB_DIR/default.store"
[[ -f "$BACKUP_DIR/default.store-wal" ]] && cp "$BACKUP_DIR/default.store-wal" "$DB_DIR/default.store-wal"
[[ -f "$BACKUP_DIR/default.store-shm" ]] && cp "$BACKUP_DIR/default.store-shm" "$DB_DIR/default.store-shm"

echo "回灌完成：$DB_DIR"
ls -lah "$DB_DIR" | rg "default\.store"
