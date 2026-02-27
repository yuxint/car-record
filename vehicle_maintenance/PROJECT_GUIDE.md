# 车辆保养记录App - 项目初始化指南

## 📋 项目概述

一款基于 Flutter + sqflite 的车辆保养记录应用，数据完全存储在本地。

## 📄 文档索引

- [产品需求文档 (PRD)](./docs/PRD.md)
- [技术方案文档](./docs/TECHNICAL.md)

## 🚀 快速开始

### 1. 环境准备

#### 安装 Flutter SDK

**Windows:**
```powershell
# 方式一：使用官方安装包
# 访问 https://flutter.dev/docs/get-started/install/windows 下载

# 方式二：使用 git 克隆
git clone https://github.com/flutter/flutter.git -b stable
# 然后将 flutter\bin 添加到系统环境变量 PATH 中
```

**macOS:**
```bash
# 使用 Homebrew 安装
brew install --cask flutter

# 或者使用 git 克隆
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
```

**Linux:**
```bash
# 使用 snap 安装 (Ubuntu)
sudo snap install flutter --classic

# 或者使用 git 克隆
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
```

#### 验证安装

```bash
# 检查 Flutter 版本
flutter --version

# 运行 Flutter Doctor 检查环境
flutter doctor
```

### 2. 初始化项目

#### 方案一：使用 flutter create 命令（推荐）

```bash
# 在当前目录创建项目
flutter create --org com.maintenance --platforms android,ios vehicle_maintenance

# 进入项目目录
cd vehicle_maintenance
```

#### 方案二：手动创建项目结构

如果你想手动创建，请参考 [技术方案文档](./docs/TECHNICAL.md) 中的目录结构。

### 3. 配置依赖

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 状态管理
  provider: ^6.1.1
  
  # 数据库
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  path: ^1.8.3
  
  # 路由
  go_router: ^13.0.0
  
  # 日期时间
  intl: ^0.19.0
  
  # 数据导出
  csv: ^5.1.1
  share_plus: ^7.2.1
  
  # 其他工具
  uuid: ^4.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

然后运行：

```bash
flutter pub get
```

### 4. 开始开发

按照以下顺序开始开发：

1. **创建数据模型** (`lib/models/`)
2. **配置数据库** (`lib/database/`)
3. **创建数据仓库** (`lib/repositories/`)
4. **实现状态管理** (`lib/providers/`)
5. **实现视图模型** (`lib/viewmodels/`)
6. **开发UI页面** (`lib/views/`)
7. **创建通用组件** (`lib/widgets/`)

## 📱 功能开发优先级

### MVP 版本 (v1.0)
- [ ] 车辆信息管理（添加、编辑、删除车辆）
- [ ] 保养记录管理（增删改查）
- [ ] 保养记录列表展示
- [ ] 自动计算与上次保养的时间差、里程差
- [ ] 基础统计功能
- [ ] 数据导出CSV

### v1.1 版本
- [ ] 保养提醒功能
- [ ] 数据可视化图表
- [ ] 保养费用趋势分析

### v1.2 版本
- [ ] 保养照片上传
- [ ] 票据管理
- [ ] 保养小贴士

## 🛠️ 开发工具推荐

### IDE
- **Android Studio / IntelliJ IDEA**（推荐，有完整Flutter支持）
- **VS Code**（轻量，配合Flutter插件）

### 调试工具
- **Flutter DevTools** - 性能分析、Widget检查
- **Android Studio Profiler** - Android性能分析
- **Xcode Instruments** - iOS性能分析

## 📚 学习资源

### Flutter 官方资源
- [Flutter 官网](https://flutter.dev)
- [Flutter 中文文档](https://flutter.cn/docs)
- [Flutter 教程](https://flutter.dev/docs/get-started/codelab)

### sqflite 使用
- [sqflite GitHub](https://github.com/tekartik/sqflite)
- [sqflite 文档](https://pub.dev/packages/sqflite)

### Provider 状态管理
- [Provider 文档](https://pub.dev/packages/provider)
- [Provider 教程](https://flutter.dev/docs/development/data-and-backend/state-mgmt/simple)

## 📞 需要帮助？

如果你在开发过程中遇到问题，可以：
1. 查看 [技术方案文档](./docs/TECHNICAL.md)
2. 参考 Flutter 官方文档
3. 在 GitHub 上搜索相关问题

## 📄 许可证

MIT License
