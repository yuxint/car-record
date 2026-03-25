#!/usr/bin/env bash
set -euo pipefail

# 将备份文件恢复到已启动模拟器的 CarRecord 容器。
# 优先按 App 备份 JSON（maintenance-export.json）恢复，兜底兼容 default.store 覆盖回灌。
# 用法：
#   scripts/sim_data_restore.sh <备份目录或JSON文件> [bundle_id]
SOURCE_PATH="${1:-}"
BUNDLE_ID="${2:-com.tx.app.CarRecord}"

if [[ -z "$SOURCE_PATH" ]]; then
  echo "请传入备份目录或 JSON 文件，例如：scripts/sim_data_restore.sh tmp/data-backup/20260316-142114" >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "未找到 xcrun，无法定位模拟器容器。" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "未找到 python3，无法执行 JSON 恢复。" >&2
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
DB_FILE="$DB_DIR/default.store"

if [[ ! -f "$DB_FILE" ]]; then
  echo "未找到数据库文件：$DB_FILE" >&2
  exit 1
fi

JSON_FILE=""
if [[ -d "$SOURCE_PATH" ]]; then
  if [[ -f "$SOURCE_PATH/maintenance-export.json" ]]; then
    JSON_FILE="$SOURCE_PATH/maintenance-export.json"
  fi
elif [[ -f "$SOURCE_PATH" ]]; then
  JSON_FILE="$SOURCE_PATH"
fi

if [[ -n "$JSON_FILE" ]]; then
  python3 - <<'PY' "$DB_FILE" "$JSON_FILE"
import datetime
import json
import pathlib
import sqlite3
import sys
import uuid

db_path = pathlib.Path(sys.argv[1])
json_path = pathlib.Path(sys.argv[2])
APPLE_REF = 978307200

conn = sqlite3.connect(str(db_path))
conn.row_factory = sqlite3.Row

def table_exists(table):
    row = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    return row is not None

def table_columns(table):
    return {row["name"] for row in conn.execute(f"PRAGMA table_info({table})")}

def uuid_to_blob(value):
    return uuid.UUID(str(value).strip()).bytes

def normalize_uuid(value):
    return str(uuid.UUID(str(value).strip())).upper()

def parse_date_yyyy_mm_dd(value):
    text = str(value).strip()
    parsed = datetime.datetime.strptime(text, "%Y-%m-%d")
    # 严格校验，避免 2026-2-3 这类非标准格式被放过。
    if parsed.strftime("%Y-%m-%d") != text:
        raise ValueError(f"日期格式错误：{text}")
    return parsed

def date_to_apple_timestamp(value):
    dt = parse_date_yyyy_mm_dd(value)
    # 与 AppDateContext 使用本地时区日期口径保持一致。
    unix = dt.timestamp()
    return unix - APPLE_REF

def unix_to_apple_timestamp(value):
    return float(value) - APPLE_REF

def normalize_profile_key(brand, model_name):
    return f"{(brand or '').strip()}|{(model_name or '').strip()}"

def next_pk(table):
    row = conn.execute(f"SELECT COALESCE(MAX(Z_PK), 0) AS max_pk FROM {table}").fetchone()
    return int(row["max_pk"] or 0) + 1

def insert_row(table, data):
    cols = table_columns(table)
    payload = {k: v for k, v in data.items() if k in cols}
    names = list(payload.keys())
    values = [payload[name] for name in names]
    placeholders = ",".join(["?"] * len(values))
    conn.execute(
        f"INSERT INTO {table} ({','.join(names)}) VALUES ({placeholders})",
        values,
    )

def entity_ent_by_names(names):
    if not table_exists("Z_PRIMARYKEY"):
        return None
    placeholders = ",".join(["?"] * len(names))
    row = conn.execute(
        f"SELECT Z_ENT, Z_NAME FROM Z_PRIMARYKEY WHERE Z_NAME IN ({placeholders}) ORDER BY Z_ENT ASC LIMIT 1",
        tuple(names),
    ).fetchone()
    return int(row["Z_ENT"]) if row else None

def update_entity_max(name, max_pk):
    if not table_exists("Z_PRIMARYKEY"):
        return
    conn.execute(
        "UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_NAME = ?",
        (int(max_pk), name),
    )

raw = json.loads(json_path.read_text(encoding="utf-8"))
if not isinstance(raw, dict):
    raise ValueError("恢复失败：JSON 根节点必须为对象。")

if "modelProfiles" not in raw or "vehicles" not in raw:
    raise ValueError("恢复失败：JSON 缺少 modelProfiles 或 vehicles，文件结构与 App 当前备份不一致。")

model_profiles = raw.get("modelProfiles")
vehicles = raw.get("vehicles")
if not isinstance(model_profiles, list) or not isinstance(vehicles, list):
    raise ValueError("恢复失败：modelProfiles/vehicles 必须为数组。")

profile_by_key = {}
for profile in model_profiles:
    key = normalize_profile_key(profile.get("brand"), profile.get("modelName"))
    if key in profile_by_key:
        raise ValueError(f"恢复失败：车型“{profile.get('brand', '')} {profile.get('modelName', '')}”重复。")
    profile_by_key[key] = profile

if not profile_by_key and vehicles:
    raise ValueError("恢复失败：备份缺少车型保养项目配置。")

car_columns = table_columns("ZCAR")
log_columns = table_columns("ZMAINTENANCELOG")
item_columns = table_columns("ZMAINTENANCEITEMOPTION")
log_item_columns = table_columns("ZMAINTENANCELOGITEM") if table_exists("ZMAINTENANCELOGITEM") else set()

has_car_disabled_raw = "ZDISABLEDITEMIDSRAW" in car_columns
has_item_owner = "ZOWNERCARID" in item_columns

car_ent = entity_ent_by_names(["Car"])
item_ent = entity_ent_by_names(["MaintenanceItemOption"])
log_ent = entity_ent_by_names(["MaintenanceLog", "MaintenanceRecord"])
log_item_ent = entity_ent_by_names(["MaintenanceLogItem", "MaintenanceRecordItem"])

conn.execute("BEGIN")
try:
    # 与 App clearAllBusinessData 对齐：清空车辆/项目/记录相关业务数据。
    if table_exists("ZMAINTENANCELOGITEM"):
        conn.execute("DELETE FROM ZMAINTENANCELOGITEM")
    conn.execute("DELETE FROM ZMAINTENANCELOG")
    conn.execute("DELETE FROM ZMAINTENANCEITEMOPTION")
    conn.execute("DELETE FROM ZCAR")

    imported_car_ids = set()
    imported_model_keys = set()
    imported_log_ids = set()

    car_pk = next_pk("ZCAR")
    item_pk = next_pk("ZMAINTENANCEITEMOPTION")
    log_pk = next_pk("ZMAINTENANCELOG")
    log_item_pk = next_pk("ZMAINTENANCELOGITEM") if table_exists("ZMAINTENANCELOGITEM") else 1

    max_car_pk = 0
    max_item_pk = 0
    max_log_pk = 0
    max_log_item_pk = 0

    for vehicle in vehicles:
        car_payload = vehicle.get("car") or {}
        car_id = normalize_uuid(car_payload.get("id"))
        if car_id in imported_car_ids:
            raise ValueError(f"恢复失败：备份内车辆ID {car_id} 重复。")
        imported_car_ids.add(car_id)

        purchase_date_text = str(car_payload.get("purchaseDate", "")).strip()
        _ = parse_date_yyyy_mm_dd(purchase_date_text)

        profile_key = normalize_profile_key(car_payload.get("brand"), car_payload.get("modelName"))
        if profile_key not in profile_by_key:
            raise ValueError(f"恢复失败：车型“{car_payload.get('brand', '')} {car_payload.get('modelName', '')}”缺少保养项目配置。")
        if profile_key in imported_model_keys:
            raise ValueError(f"恢复失败：车型“{car_payload.get('brand', '')} {car_payload.get('modelName', '')}”重复，单一车型仅允许一辆车。")
        imported_model_keys.add(profile_key)

        current_car_pk = car_pk
        car_pk += 1
        max_car_pk = max(max_car_pk, current_car_pk)

        car_row = {
            "Z_PK": current_car_pk,
            "Z_ENT": car_ent,
            "Z_OPT": 1,
            "ZID": uuid_to_blob(car_id),
            "ZBRAND": car_payload.get("brand", ""),
            "ZMODELNAME": car_payload.get("modelName", ""),
            "ZMILEAGE": int(car_payload.get("mileage", 0) or 0),
            "ZPURCHASEDATE": date_to_apple_timestamp(purchase_date_text),
        }
        if has_car_disabled_raw:
            car_row["ZDISABLEDITEMIDSRAW"] = str(car_payload.get("disabledItemIDsRaw", "") or "")
        insert_row("ZCAR", car_row)

        profile = profile_by_key[profile_key]
        service_items = profile.get("serviceItems") or []
        if not isinstance(service_items, list):
            raise ValueError("恢复失败：serviceItems 必须为数组。")

        item_name_to_id = {}
        item_key_to_id = {}
        profile_item_keys = set()
        for item in service_items:
            item_name = str(item.get("name", "")).strip()
            if not item_name:
                raise ValueError("恢复失败：保养项目名称不能为空。")
            if item_name in item_name_to_id:
                raise ValueError(
                    f"恢复失败：车型“{profile.get('brand', '')} {profile.get('modelName', '')}”存在重复项目“{item_name}”。"
                )
            item_id = normalize_uuid(item.get("id"))
            item_name_to_id[item_name] = item_id
            item_key = str(item.get("catalogKey", "") or "").strip()
            if item_key:
                if item_key in profile_item_keys:
                    raise ValueError(
                        f"恢复失败：车型“{profile.get('brand', '')} {profile.get('modelName', '')}”存在重复项目 key “{item_key}”。"
                    )
                profile_item_keys.add(item_key)
                item_key_to_id[item_key] = item_id

            current_item_pk = item_pk
            item_pk += 1
            max_item_pk = max(max_item_pk, current_item_pk)
            item_row = {
                "Z_PK": current_item_pk,
                "Z_ENT": item_ent,
                "Z_OPT": 1,
                "ZID": uuid_to_blob(item_id),
                "ZNAME": item_name,
                "ZISDEFAULT": 1 if bool(item.get("isDefault", False)) else 0,
                "ZCATALOGKEY": item.get("catalogKey"),
                "ZREMINDBYMILEAGE": 1 if bool(item.get("remindByMileage", False)) else 0,
                "ZMILEAGEINTERVAL": int(item.get("mileageInterval", 0) or 0),
                "ZREMINDBYTIME": 1 if bool(item.get("remindByTime", False)) else 0,
                "ZMONTHINTERVAL": int(item.get("monthInterval", 0) or 0),
                "ZWARNINGSTARTPERCENT": int(item.get("warningStartPercent", 0) or 0),
                "ZDANGERSTARTPERCENT": int(item.get("dangerStartPercent", 0) or 0),
                "ZCREATEDAT": unix_to_apple_timestamp(float(item.get("createdAt", 0) or 0)),
            }
            if has_item_owner:
                item_row["ZOWNERCARID"] = uuid_to_blob(car_id)
            insert_row("ZMAINTENANCEITEMOPTION", item_row)

        service_logs = vehicle.get("serviceLogs") or []
        if not isinstance(service_logs, list):
            raise ValueError("恢复失败：serviceLogs 必须为数组。")

        for log in service_logs:
            log_id = normalize_uuid(log.get("id"))
            if log_id in imported_log_ids:
                raise ValueError(f"恢复失败：备份内保养记录ID {log_id} 重复。")
            imported_log_ids.add(log_id)

            log_date_text = str(log.get("date", "")).strip()
            _ = parse_date_yyyy_mm_dd(log_date_text)

            raw_names = log.get("itemNames") or []
            if not isinstance(raw_names, list):
                raise ValueError("恢复失败：itemNames 必须为数组。")

            item_ids = []
            seen_item_ids = set()
            for name in raw_names:
                normalized_name = str(name).strip()
                if not normalized_name:
                    continue
                item_id = item_key_to_id.get(normalized_name) or item_name_to_id.get(normalized_name)
                if not item_id:
                    raise ValueError(f"恢复失败：项目“{normalized_name}”未在车型配置中声明。")
                if item_id in seen_item_ids:
                    continue
                seen_item_ids.add(item_id)
                item_ids.append(item_id)
            if not item_ids:
                raise ValueError("恢复失败：保养项目不能为空。")

            item_ids_raw = "|".join(item_ids)
            cycle_key = f"{car_id}|{log_date_text}"

            current_log_pk = log_pk
            log_pk += 1
            max_log_pk = max(max_log_pk, current_log_pk)
            log_row = {
                "Z_PK": current_log_pk,
                "Z_ENT": log_ent,
                "Z_OPT": 1,
                "ZID": uuid_to_blob(log_id),
                "ZCAR": current_car_pk,
                "ZDATE": date_to_apple_timestamp(log_date_text),
                "ZITEMIDSRAW": item_ids_raw,
                "ZCOST": float(log.get("cost", 0) or 0),
                "ZMILEAGE": int(log.get("mileage", 0) or 0),
                "ZNOTE": str(log.get("note", "") or ""),
                "ZCYCLEKEY": cycle_key,
            }
            insert_row("ZMAINTENANCELOG", log_row)

            if log_item_columns:
                for item_id in item_ids:
                    current_log_item_pk = log_item_pk
                    log_item_pk += 1
                    max_log_item_pk = max(max_log_item_pk, current_log_item_pk)
                    insert_row(
                        "ZMAINTENANCELOGITEM",
                        {
                            "Z_PK": current_log_item_pk,
                            "Z_ENT": log_item_ent,
                            "Z_OPT": 1,
                            "ZID": uuid_to_blob(str(uuid.uuid4())),
                            "ZLOG": current_log_pk,
                            "ZITEMID": uuid_to_blob(item_id),
                            "ZCYCLEITEMKEY": f"{cycle_key}|{item_id}",
                            "ZCREATEDAT": date_to_apple_timestamp(log_date_text),
                        },
                    )

    # 同步主键游标，避免后续 App 插入撞主键。
    if max_car_pk:
        update_entity_max("Car", max_car_pk)
    if max_item_pk:
        update_entity_max("MaintenanceItemOption", max_item_pk)
    if max_log_pk:
        update_entity_max("MaintenanceLog", max_log_pk)
        update_entity_max("MaintenanceRecord", max_log_pk)
    if max_log_item_pk:
        update_entity_max("MaintenanceLogItem", max_log_item_pk)
        update_entity_max("MaintenanceRecordItem", max_log_item_pk)

    conn.commit()
except Exception:
    conn.rollback()
    raise
finally:
    conn.close()

print("JSON 恢复完成")
PY

  echo "恢复完成（JSON 导入）：$JSON_FILE"
  ls -lah "$DB_DIR" | rg "default\.store"
  exit 0
fi

if [[ ! -d "$SOURCE_PATH" ]]; then
  echo "传入路径不存在：$SOURCE_PATH" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_PATH/default.store" ]]; then
  echo "目录中既没有 maintenance-export.json，也没有 default.store：$SOURCE_PATH" >&2
  exit 1
fi

# 先清理旧库，再覆盖回灌，避免 WAL/SHM 与主库不匹配。
rm -f "$DB_DIR/default.store" "$DB_DIR/default.store-wal" "$DB_DIR/default.store-shm"
cp "$SOURCE_PATH/default.store" "$DB_DIR/default.store"
[[ -f "$SOURCE_PATH/default.store-wal" ]] && cp "$SOURCE_PATH/default.store-wal" "$DB_DIR/default.store-wal"
[[ -f "$SOURCE_PATH/default.store-shm" ]] && cp "$SOURCE_PATH/default.store-shm" "$DB_DIR/default.store-shm"

echo "恢复完成（default.store 覆盖回灌）：$DB_DIR"
ls -lah "$DB_DIR" | rg "default\.store"
