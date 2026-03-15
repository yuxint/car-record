# car-record

本仓库包含 `CarRecord` iOS 项目，以及一套“无 Apple Developer Program 付费账号”的自动化分发方案：
- CI 构建未签名 IPA（供 SideStore 重签安装）
- 自动发布 GitHub Release（外网）
- 生成 SideStore 源文件与安装落地页
- 可同步到局域网静态目录（Nginx/NAS）

## 项目结构

- `ios/CarRecord`: SwiftUI + SwiftData 源码
- `CarRecord/CarRecord.xcodeproj`: iOS 工程
- `.github/workflows/ios-ipa-release.yml`: 自动构建与发布工作流
- `scripts/build_release_artifacts.sh`: 构建 IPA 并生成标准发布产物
- `scripts/sync_to_lan.sh`: 将发布产物同步到局域网目录

## 发布产物

每次发布会产出以下文件（位于 `release/`）：
- `CarRecord.ipa`
- `source.json`（外网 SideStore 源）
- `source.lan.json`（局域网 SideStore 源）
- `install.html`（外网安装页）
- `install.lan.html`（局域网安装页）
- `sha256.txt`
- `build-meta.json`

## GitHub Actions 配置

工作流：`.github/workflows/ios-ipa-release.yml`

触发方式：
1. 推送到 `main`
2. 手动触发（Actions -> `ios-ipa-release` -> Run workflow）

建议在 GitHub 仓库设置以下 Secret：
- `LAN_BASE_URL`：可选，局域网托管基地址，例如 `http://nas.local/car-record`
- `ICON_URL`：可选，SideStore 应用图标 URL（不填时默认使用 GitHub 头像）

## 固定安装链接（推荐）

CI 成功后会自动发布固定链接（始终指向最新版本）：
- 安装页：`https://<你的GitHub用户名>.github.io/car-record/install.html`
- SideStore 源：`https://<你的GitHub用户名>.github.io/car-record/source.json`
- 页面会显示当次 `release_tag` 与构建时间（Asia/Shanghai + UTC）。
- SideStore `version` 与 App 内版本号一致：格式为 `主版本.次版本.CI_RUN_NUMBER`（例如 `1.0.125`），每次 push 触发 CI 自动递增；`buildVersion` 使用 `CI_RUN_NUMBER`。
- `source.json` 地址固定不变（gh-pages），但内部 `downloadURL` 指向当次 release tag 直链，确保对应最新构建产物。
- `downloadURL` 指向唯一文件名（`CarRecord-<release_tag>.ipa`），从根源规避 SideStore 旧包缓存命中。

首次使用请在仓库 Settings -> Pages 中确认：
- Source 为 `Deploy from a branch`
- Branch 选择 `gh-pages`，目录 `/ (root)`

## iPhone 安装方式（SideStore）

1. 在 iPhone 安装 SideStore 并登录你的 Apple ID。
2. 打开固定安装页，点击“**一键打开 SideStore 添加源**”（页面同时提供 AltStore 兼容入口）或手动复制固定 `source.json` 链接。
3. 在 SideStore 添加该源并安装 `CarRecord`。
4. 每 7 天在 SideStore 执行续签。

注意：无付费开发者账号时，不支持 Safari 企业签名式一键直装。

## 同步到局域网

先确保你已经有本地 `release/` 产物，再执行：

```bash
scripts/sync_to_lan.sh --src ./release --dest /path/to/your/lan/www/car-record
```

同步后，局域网目录默认包含：
- `source.json`（优先为 LAN 版）
- `install.html`（优先为 LAN 版）
- `CarRecord.ipa`
- `sha256.txt`
- `build-meta.json`
