# car-record

本仓库包含 `CarRecord` iOS 项目，以及一套“无 Apple Developer Program 付费账号”的自动化分发方案：
- CI 构建未签名 IPA（供 AltStore 重签安装）
- 自动发布 GitHub Release（外网）
- 生成 AltStore 源文件与安装落地页
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
- `source.json`（外网 AltStore 源）
- `source.lan.json`（局域网 AltStore 源）
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

## iPhone 安装方式（AltStore）

1. 在 iPhone 安装 AltStore 并登录你的 Apple ID。
2. 打开 Release 里的 `source.json`（外网）或 `source.lan.json`（内网）链接。
3. 在 AltStore 添加该源并安装 `CarRecord`。
4. 每 7 天在 AltStore 执行续签。

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
