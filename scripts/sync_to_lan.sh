#!/usr/bin/env bash
set -euo pipefail

# 模块职责：把标准化发布产物同步到局域网静态目录（Nginx/NAS 可直接托管）。
# 关键逻辑：优先使用 LAN 版源文件（source.lan.json/install.lan.html），保证内网链接可直接安装。

usage() {
  cat <<USAGE
用法：
  scripts/sync_to_lan.sh --src <发布产物目录> --dest <局域网静态目录>

示例：
  scripts/sync_to_lan.sh --src ./release --dest /Volumes/nas/www/car-record
USAGE
}

SRC_DIR=""
DEST_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src)
      SRC_DIR="$2"
      shift 2
      ;;
    --dest)
      DEST_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${SRC_DIR}" || -z "${DEST_DIR}" ]]; then
  echo "必须同时提供 --src 和 --dest" >&2
  usage
  exit 1
fi

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "源目录不存在: ${SRC_DIR}" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"

for file in CarRecord.ipa sha256.txt build-meta.json; do
  if [[ ! -f "${SRC_DIR}/${file}" ]]; then
    echo "缺少关键产物: ${SRC_DIR}/${file}" >&2
    exit 1
  fi
  cp -f "${SRC_DIR}/${file}" "${DEST_DIR}/${file}"
done

# 关键逻辑：若存在带发布标签的 IPA，一并同步，保证 LAN 版 source.json 可直接命中。
if ls "${SRC_DIR}"/CarRecord-*.ipa >/dev/null 2>&1; then
  cp -f "${SRC_DIR}"/CarRecord-*.ipa "${DEST_DIR}/"
fi

if [[ -f "${SRC_DIR}/source.lan.json" ]]; then
  cp -f "${SRC_DIR}/source.lan.json" "${DEST_DIR}/source.json"
else
  cp -f "${SRC_DIR}/source.json" "${DEST_DIR}/source.json"
fi

if [[ -f "${SRC_DIR}/install.lan.html" ]]; then
  cp -f "${SRC_DIR}/install.lan.html" "${DEST_DIR}/install.html"
else
  cp -f "${SRC_DIR}/install.html" "${DEST_DIR}/install.html"
fi

if [[ -f "${SRC_DIR}/source.json" ]]; then
  cp -f "${SRC_DIR}/source.json" "${DEST_DIR}/source.public.json"
fi
if [[ -f "${SRC_DIR}/install.html" ]]; then
  cp -f "${SRC_DIR}/install.html" "${DEST_DIR}/install.public.html"
fi

echo "同步完成：${DEST_DIR}"
ls -lh "${DEST_DIR}"
