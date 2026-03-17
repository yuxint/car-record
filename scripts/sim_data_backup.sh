#!/usr/bin/env bash
set -euo pipefail

# 备份 iOS 模拟器中 CarRecord 的本地 SwiftData 文件，并额外导出可导回的 JSON。
BUNDLE_ID="${1:-com.tx.app.CarRecord}"
BACKUP_ROOT="${2:-$(pwd)/tmp/data-backup}"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "未找到 xcrun，无法定位模拟器容器。" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "未找到 sqlite3，无法导出数据库。" >&2
  exit 1
fi

DATA_CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null || true)"
if [[ -z "$DATA_CONTAINER" ]]; then
  echo "未找到已启动模拟器中的应用容器：$BUNDLE_ID" >&2
  echo "请先启动模拟器并确保应用已安装。" >&2
  exit 1
fi

DB_DIR="$DATA_CONTAINER/Library/Application Support"
DB_FILE="$DB_DIR/default.store"
if [[ ! -f "$DB_FILE" ]]; then
  echo "未找到数据库文件：$DB_FILE" >&2
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TS"
mkdir -p "$BACKUP_DIR"

cp "$DB_FILE" "$BACKUP_DIR/default.store"
[[ -f "$DB_FILE-wal" ]] && cp "$DB_FILE-wal" "$BACKUP_DIR/default.store-wal"
[[ -f "$DB_FILE-shm" ]] && cp "$DB_FILE-shm" "$BACKUP_DIR/default.store-shm"
sqlite3 "$DB_FILE" .dump > "$BACKUP_DIR/default.store.sql"

# 统计核心业务表数量，便于备份后快速核对。
sqlite3 "$DB_FILE" "
SELECT 'ZCAR', COUNT(*) FROM ZCAR
UNION ALL
SELECT 'ZMAINTENANCELOG', COUNT(*) FROM ZMAINTENANCELOG
UNION ALL
SELECT 'ZMAINTENANCEITEMOPTION', COUNT(*) FROM ZMAINTENANCEITEMOPTION
UNION ALL
SELECT 'ZFUELLOG', COUNT(*) FROM ZFUELLOG
UNION ALL
SELECT 'ZMAINTENANCELOGITEM', COUNT(*) FROM ZMAINTENANCELOGITEM;
" > "$BACKUP_DIR/row-counts.txt" || true

# 额外导出应用内可直接“导入保养数据”的 JSON（当前按 version=1 结构）。
python3 - <<'PY' "$DB_FILE" "$BACKUP_DIR/maintenance-export-v1.json"
import sqlite3, json, datetime, pathlib, sys

db_path = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])
conn = sqlite3.connect(str(db_path))
conn.row_factory = sqlite3.Row
APPLE_REF = 978307200

def uuid_from_blob(blob):
    if blob is None:
        return ""
    h = blob.hex()
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"

def date_text(raw):
    if raw is None:
        return ""
    ts = float(raw) + APPLE_REF
    return datetime.datetime.utcfromtimestamp(ts).strftime('%Y-%m-%d')

options = {}
for row in conn.execute("SELECT ZID, ZNAME FROM ZMAINTENANCEITEMOPTION"):
    options[uuid_from_blob(row["ZID"]).upper()] = row["ZNAME"] or ""

vehicles = []
for car in conn.execute(
    "SELECT Z_PK, ZID, ZBRAND, ZMODELNAME, ZMILEAGE, ZPURCHASEDATE FROM ZCAR ORDER BY ZPURCHASEDATE DESC, Z_PK DESC"
):
    car_pk = car["Z_PK"]
    logs = []
    for log in conn.execute(
        "SELECT ZID, ZDATE, ZITEMIDSRAW, ZCOST, ZMILEAGE, ZNOTE, Z_PK "
        "FROM ZMAINTENANCELOG WHERE ZCAR = ? ORDER BY ZDATE ASC, ZMILEAGE ASC, Z_PK ASC",
        (car_pk,),
    ):
        seen = set()
        item_names = []
        raw_ids = (log["ZITEMIDSRAW"] or "").strip()
        if raw_ids:
            for token in raw_ids.split("|"):
                key = token.strip().upper()
                if not key or key in seen:
                    continue
                seen.add(key)
                name = options.get(key)
                if name:
                    item_names.append(name)

        logs.append(
            {
                "id": uuid_from_blob(log["ZID"]),
                "date": date_text(log["ZDATE"]),
                "itemNames": item_names,
                "cost": float(log["ZCOST"] or 0),
                "mileage": int(log["ZMILEAGE"] or 0),
                "note": log["ZNOTE"] or "",
            }
        )

    vehicles.append(
        {
            "car": {
                "id": uuid_from_blob(car["ZID"]),
                "brand": car["ZBRAND"] or "",
                "modelName": car["ZMODELNAME"] or "",
                "mileage": int(car["ZMILEAGE"] or 0),
                "purchaseDate": date_text(car["ZPURCHASEDATE"]),
            },
            "maintenanceLogs": logs,
        }
    )

payload = {"version": 1, "vehicles": vehicles}
out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
print(out_path)
PY

echo "备份完成：$BACKUP_DIR"
ls -lah "$BACKUP_DIR"
