#!/usr/bin/env bash
set -euo pipefail

# 模块职责：构建未签名 iOS IPA，并生成 AltStore 源与安装落地页等标准化产物。
# 关键逻辑：通过 xcodebuild 禁用签名构建真机包，再手工打包 Payload 生成可重签名 IPA。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-CarRecord}"
SCHEME="${SCHEME:-CarRecord}"
PROJECT_PATH="${PROJECT_PATH:-${ROOT_DIR}/CarRecord/CarRecord.xcodeproj}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/release}"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/.build}"

RELEASE_TAG="${RELEASE_TAG:-local-$(date +%Y%m%d-%H%M)}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.tx.app.CarRecord}"
ALTSTORE_SOURCE_NAME="${ALTSTORE_SOURCE_NAME:-CarRecord Source}"
APP_DESCRIPTION="${APP_DESCRIPTION:-CarRecord 本地优先车辆记录应用（需通过 AltStore 安装）。}"
DEVELOPER_NAME="${DEVELOPER_NAME:-tx}"
ICON_URL="${ICON_URL:-}"
PUBLIC_RELEASE_BASE_URL="${PUBLIC_RELEASE_BASE_URL:-}"
LAN_BASE_URL="${LAN_BASE_URL:-}"

if [[ -z "${ICON_URL}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  # 关键逻辑：AltStore 要求 apps[].iconURL 非空，默认使用仓库拥有者头像作为稳定图标地址。
  ICON_URL="https://github.com/${GITHUB_REPOSITORY%%/*}.png?size=256"
fi
if [[ -z "${ICON_URL}" ]]; then
  ICON_URL="https://github.githubassets.com/favicons/favicon.png"
fi

if [[ -z "${PUBLIC_RELEASE_BASE_URL}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  PUBLIC_RELEASE_BASE_URL="https://github.com/${GITHUB_REPOSITORY}/releases/download/${RELEASE_TAG}"
fi
if [[ -z "${PUBLIC_RELEASE_BASE_URL}" ]]; then
  PUBLIC_RELEASE_BASE_URL="https://example.com/${APP_NAME}/${RELEASE_TAG}"
fi

PUBLIC_RELEASE_BASE_URL="${PUBLIC_RELEASE_BASE_URL%/}"
LAN_BASE_URL="${LAN_BASE_URL%/}"

mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}"
rm -rf "${OUTPUT_DIR:?}"/*

DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
PAYLOAD_DIR="${BUILD_DIR}/Payload"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release-iphoneos/${APP_NAME}.app"
IPA_PATH="${OUTPUT_DIR}/${APP_NAME}.ipa"

echo "[1/5] 构建未签名 iOS 真机包..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build >/tmp/xcodebuild.log

if [[ ! -d "${APP_PATH}" ]]; then
  echo "构建失败：未找到 ${APP_PATH}" >&2
  tail -n 120 /tmp/xcodebuild.log >&2 || true
  exit 1
fi

echo "[2/5] 打包 IPA..."
rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/"
(
  cd "${BUILD_DIR}"
  /usr/bin/zip -qry "${IPA_PATH}" Payload
)

IPA_SIZE_BYTES="$(stat -f%z "${IPA_PATH}")"
SHA256="$(shasum -a 256 "${IPA_PATH}" | awk '{print $1}')"

echo "${SHA256}  ${APP_NAME}.ipa" >"${OUTPUT_DIR}/sha256.txt"

MARKETING_VERSION="$(xcodebuild -showBuildSettings -project "${PROJECT_PATH}" -scheme "${SCHEME}" 2>/dev/null | awk -F' = ' '/MARKETING_VERSION/ {print $2; exit}')"
CURRENT_PROJECT_VERSION="$(xcodebuild -showBuildSettings -project "${PROJECT_PATH}" -scheme "${SCHEME}" 2>/dev/null | awk -F' = ' '/CURRENT_PROJECT_VERSION/ {print $2; exit}')"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
APP_VERSION="${MARKETING_VERSION}"
BUILD_NUMBER="${CURRENT_PROJECT_VERSION}"
VERSION_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

IPA_PUBLIC_URL="${PUBLIC_RELEASE_BASE_URL}/${APP_NAME}.ipa"
SOURCE_PUBLIC_URL="${PUBLIC_RELEASE_BASE_URL}/source.json"
INSTALL_PUBLIC_URL="${PUBLIC_RELEASE_BASE_URL}/install.html"

if [[ -n "${LAN_BASE_URL}" ]]; then
  IPA_LAN_URL="${LAN_BASE_URL}/${APP_NAME}.ipa"
  SOURCE_LAN_URL="${LAN_BASE_URL}/source.json"
  INSTALL_LAN_URL="${LAN_BASE_URL}/install.html"
else
  # 未配置局域网时回退到外网地址，确保产物结构稳定且 CI 不因缺文件失败。
  IPA_LAN_URL="${IPA_PUBLIC_URL}"
  SOURCE_LAN_URL="${SOURCE_PUBLIC_URL}"
  INSTALL_LAN_URL="${INSTALL_PUBLIC_URL}"
fi

echo "[3/5] 生成 AltStore 源文件..."
cat >"${OUTPUT_DIR}/source.json" <<JSON
{
  "name": "${ALTSTORE_SOURCE_NAME}",
  "apps": [
    {
      "name": "${APP_NAME}",
      "bundleIdentifier": "${BUNDLE_IDENTIFIER}",
      "developerName": "${DEVELOPER_NAME}",
      "localizedDescription": "${APP_DESCRIPTION}",
      "iconURL": "${ICON_URL}",
      "versions": [
        {
          "version": "${APP_VERSION}",
          "buildVersion": "${BUILD_NUMBER}",
          "date": "${VERSION_DATE}",
          "downloadURL": "${IPA_PUBLIC_URL}",
          "size": ${IPA_SIZE_BYTES},
          "minOSVersion": "17.0"
        }
      ]
    }
  ]
}
JSON

cat >"${OUTPUT_DIR}/source.lan.json" <<JSON
{
  "name": "${ALTSTORE_SOURCE_NAME}${LAN_BASE_URL:+ (LAN)}",
  "apps": [
    {
      "name": "${APP_NAME}",
      "bundleIdentifier": "${BUNDLE_IDENTIFIER}",
      "developerName": "${DEVELOPER_NAME}",
      "localizedDescription": "${APP_DESCRIPTION}",
      "iconURL": "${ICON_URL}",
      "versions": [
        {
          "version": "${APP_VERSION}",
          "buildVersion": "${BUILD_NUMBER}",
          "date": "${VERSION_DATE}",
          "downloadURL": "${IPA_LAN_URL}",
          "size": ${IPA_SIZE_BYTES},
          "minOSVersion": "17.0"
        }
      ]
    }
  ]
}
JSON

echo "[4/5] 生成安装落地页..."
cat >"${OUTPUT_DIR}/install.html" <<HTML
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${APP_NAME} 安装页</title>
  <style>
    :root { color-scheme: light; --bg:#f6f9fc; --card:#fff; --text:#112; --muted:#526; --line:#d7dfeb; --primary:#1363df; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: "PingFang SC", "SF Pro Text", "Helvetica Neue", sans-serif; background: linear-gradient(180deg, #eef5ff 0%, var(--bg) 100%); color: var(--text); }
    .wrap { max-width: 980px; margin: 24px auto; padding: 0 16px 40px; }
    .card { background: var(--card); border: 1px solid var(--line); border-radius: 14px; padding: 18px; margin-bottom: 14px; box-shadow: 0 8px 24px rgba(26, 40, 74, .06); }
    h1 { margin: 0 0 6px; font-size: 24px; }
    p { margin: 6px 0; line-height: 1.6; }
    a.btn { display: inline-block; margin: 8px 8px 0 0; padding: 10px 12px; border-radius: 10px; text-decoration: none; background: var(--primary); color: #fff; font-weight: 600; }
    .mono { font-family: ui-monospace, Menlo, monospace; font-size: 13px; word-break: break-all; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 12px; }
    img.qr { width: 160px; height: 160px; border: 1px solid var(--line); border-radius: 10px; }
    .warn { color: #a63a00; font-weight: 600; }
  </style>
</head>
<body>
  <main class="wrap">
    <section class="card">
      <h1>${APP_NAME} 安装说明</h1>
      <p>版本：<strong>${APP_VERSION}</strong>（Build ${BUILD_NUMBER}）</p>
      <p>构建时间（UTC）：${VERSION_DATE}</p>
      <p class="warn">无 Apple Developer Program 付费账号时，不能 Safari 一键企业直装；请使用 AltStore 安装并每 7 天续签。</p>
      <a class="btn" href="${IPA_PUBLIC_URL}">下载 IPA（外网）</a>
      <a class="btn" href="${SOURCE_PUBLIC_URL}">AltStore 源（外网）</a>
      <a class="btn" href="altstore://source?url=${SOURCE_PUBLIC_URL}">一键打开 AltStore 添加源</a>
      <a class="btn" href="${INSTALL_PUBLIC_URL}">当前页面（外网）</a>
    </section>

    <section class="card grid">
      <div>
        <h3>外网入口</h3>
        <p>AltStore 源：</p>
        <p class="mono">${SOURCE_PUBLIC_URL}</p>
        <img class="qr" src="https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${SOURCE_PUBLIC_URL}" alt="外网源二维码" />
      </div>
      <div>
        <h3>局域网入口</h3>
        <p>AltStore 源：</p>
        <p class="mono">${SOURCE_LAN_URL:-未配置 LAN_BASE_URL}</p>
        <img class="qr" src="https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${SOURCE_LAN_URL:-LAN_NOT_CONFIGURED}" alt="局域网源二维码" />
      </div>
    </section>

    <section class="card">
      <h3>建议流程</h3>
      <p>1. iPhone 安装 AltStore，并登录你的 Apple ID。</p>
      <p>2. 在 AltStore 添加上面的源地址（外网或局域网）。</p>
      <p>3. 选择 ${APP_NAME} 安装，首次安装后信任开发者证书。</p>
      <p>4. 每 7 天在 AltStore 里执行续签，避免 App 失效。</p>
    </section>
  </main>
</body>
</html>
HTML

sed \
  -e "s|${IPA_PUBLIC_URL}|${IPA_LAN_URL}|g" \
  -e "s|${SOURCE_PUBLIC_URL}|${SOURCE_LAN_URL}|g" \
  -e "s|${INSTALL_PUBLIC_URL}|${INSTALL_LAN_URL}|g" \
  "${OUTPUT_DIR}/install.html" >"${OUTPUT_DIR}/install.lan.html"

echo "[5/5] 生成构建元数据..."
cat >"${OUTPUT_DIR}/build-meta.json" <<JSON
{
  "git_sha": "${GITHUB_SHA:-$(git -C "${ROOT_DIR}" rev-parse HEAD)}",
  "build_time": "${VERSION_DATE}",
  "version": "${APP_VERSION}",
  "release_tag": "${RELEASE_TAG}",
  "artifact_urls": {
    "public_base_url": "${PUBLIC_RELEASE_BASE_URL}",
    "ipa": "${IPA_PUBLIC_URL}",
    "source": "${SOURCE_PUBLIC_URL}",
    "install": "${INSTALL_PUBLIC_URL}",
    "lan_base_url": "${LAN_BASE_URL}",
    "lan_ipa": "${IPA_LAN_URL}",
    "lan_source": "${SOURCE_LAN_URL}",
    "lan_install": "${INSTALL_LAN_URL}"
  }
}
JSON

echo "构建完成，产物目录：${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"
