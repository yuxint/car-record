#!/usr/bin/env bash
set -euo pipefail

# 备份 iOS 模拟器中 CarRecord 的本地 SwiftData 文件，并额外导出与 App 一致的备份 JSON。
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

# 额外导出应用内可直接“恢复数据”的 JSON（结构与 MyDataTransferPayload 一致）。
python3 - <<'PY' "$DB_FILE" "$BACKUP_DIR/maintenance-export.json"
import sqlite3, json, datetime, pathlib, sys

db_path = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])
conn = sqlite3.connect(str(db_path))
conn.row_factory = sqlite3.Row
APPLE_REF = 978307200

def table_columns(table):
    return {row["name"] for row in conn.execute(f"PRAGMA table_info({table})")}

def uuid_from_blob(blob):
    if blob is None:
        return ""
    h = blob.hex()
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"

def date_text(raw):
    if raw is None:
        return ""
    ts = float(raw) + APPLE_REF
    # 与 AppDateContext.formatShortDate 口径一致：使用本地时区日期。
    return datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d')

def parse_item_ids(raw):
    if not raw:
        return []
    parsed = []
    seen = set()
    for token in str(raw).split("|"):
        token = token.strip().upper()
        if not token or token in seen:
            continue
        seen.add(token)
        parsed.append(token)
    return parsed

car_columns = table_columns("ZCAR")
item_columns = table_columns("ZMAINTENANCEITEMOPTION")

has_disabled_item_ids = "ZDISABLEDITEMIDSRAW" in car_columns
has_owner_car_id = "ZOWNERCARID" in item_columns

car_query_cols = ["Z_PK", "ZID", "ZBRAND", "ZMODELNAME", "ZMILEAGE", "ZPURCHASEDATE"]
if has_disabled_item_ids:
    car_query_cols.append("ZDISABLEDITEMIDSRAW")

item_query_cols = [
    "ZID",
    "ZNAME",
    "ZISDEFAULT",
    "ZCATALOGKEY",
    "ZREMINDBYMILEAGE",
    "ZMILEAGEINTERVAL",
    "ZREMINDBYTIME",
    "ZMONTHINTERVAL",
    "ZWARNINGSTARTPERCENT",
    "ZDANGERSTARTPERCENT",
    "ZCREATEDAT",
]
if has_owner_car_id:
    item_query_cols.append("ZOWNERCARID")

options = []
for row in conn.execute(
    f"SELECT {', '.join(item_query_cols)} FROM ZMAINTENANCEITEMOPTION ORDER BY ZCREATEDAT ASC, Z_PK ASC"
):
    owner_car_id = uuid_from_blob(row["ZOWNERCARID"]) if has_owner_car_id else None
    options.append(
        {
            "id": uuid_from_blob(row["ZID"]),
            "name": (row["ZNAME"] or "").strip(),
            "ownerCarID": owner_car_id,
            "isDefault": bool(row["ZISDEFAULT"] or 0),
            "catalogKey": row["ZCATALOGKEY"],
            "remindByMileage": bool(row["ZREMINDBYMILEAGE"] or 0),
            "mileageInterval": int(row["ZMILEAGEINTERVAL"] or 0),
            "remindByTime": bool(row["ZREMINDBYTIME"] or 0),
            "monthInterval": int(row["ZMONTHINTERVAL"] or 0),
            "warningStartPercent": int(row["ZWARNINGSTARTPERCENT"] or 0),
            "dangerStartPercent": int(row["ZDANGERSTARTPERCENT"] or 0),
            "createdAt": float(row["ZCREATEDAT"] or 0) + APPLE_REF,
        }
    )

def scoped_options(car_id):
    if has_owner_car_id:
        return [opt for opt in options if opt["ownerCarID"] == car_id]
    return options

vehicles = []
model_profiles = []
profile_keys = set()
for car in conn.execute(
    f"SELECT {', '.join(car_query_cols)} FROM ZCAR ORDER BY ZPURCHASEDATE DESC, Z_PK DESC"
):
    car_pk = car["Z_PK"]
    car_id = uuid_from_blob(car["ZID"])
    car_scoped_options = scoped_options(car_id)
    option_export_token_by_id = {
        opt["id"].upper(): ((opt.get("catalogKey") or "").strip() or (opt.get("name") or ""))
        for opt in car_scoped_options
        if opt["id"]
    }

    profile_key = f"{(car['ZBRAND'] or '').strip()}|{(car['ZMODELNAME'] or '').strip()}"
    if profile_key not in profile_keys:
        profile_keys.add(profile_key)
        model_profiles.append(
            {
                "brand": car["ZBRAND"] or "",
                "modelName": car["ZMODELNAME"] or "",
                "serviceItems": [
                    {
                        "id": opt["id"],
                        "name": opt["name"],
                        "isDefault": opt["isDefault"],
                        "catalogKey": opt["catalogKey"],
                        "remindByMileage": opt["remindByMileage"],
                        "mileageInterval": opt["mileageInterval"],
                        "remindByTime": opt["remindByTime"],
                        "monthInterval": opt["monthInterval"],
                        "warningStartPercent": opt["warningStartPercent"],
                        "dangerStartPercent": opt["dangerStartPercent"],
                        "createdAt": opt["createdAt"],
                    }
                    for opt in car_scoped_options
                ],
            }
        )

    logs = []
    for log in conn.execute(
        "SELECT ZID, ZDATE, ZITEMIDSRAW, ZCOST, ZMILEAGE, ZNOTE, Z_PK "
        "FROM ZMAINTENANCELOG WHERE ZCAR = ? ORDER BY ZDATE ASC, ZMILEAGE ASC, Z_PK ASC",
        (car_pk,),
    ):
        item_names = []
        for item_id in parse_item_ids(log["ZITEMIDSRAW"]):
            token = option_export_token_by_id.get(item_id)
            if token:
                item_names.append(token)

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
                "id": car_id,
                "brand": car["ZBRAND"] or "",
                "modelName": car["ZMODELNAME"] or "",
                "mileage": int(car["ZMILEAGE"] or 0),
                "disabledItemIDsRaw": (car["ZDISABLEDITEMIDSRAW"] or "") if has_disabled_item_ids else "",
                "purchaseDate": date_text(car["ZPURCHASEDATE"]),
            },
            "serviceLogs": logs,
        }
    )

payload = {"modelProfiles": model_profiles, "vehicles": vehicles}
out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
print(out_path)
PY

echo "备份完成：$BACKUP_DIR"
ls -lah "$BACKUP_DIR"
