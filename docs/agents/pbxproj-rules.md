# Xcode 项目文件更新规则

当“文件清单或路径”变化时，需要检查并更新 `CarRecord/CarRecord.xcodeproj/project.pbxproj`。

## 需要检查/更新的场景

- 新增 Swift 文件且要参与编译。
- 删除 Swift 文件，避免残留引用。
- 移动或重命名 Swift 文件（尤其跨目录）。
- 调整目录结构（如 Feature 从平铺改为分层目录）。
- 新增/删除需要进 Build Phases 的资源文件。

## 一般不需要更新的场景

- 仅修改现有 Swift 文件内容，不改路径与文件名。
- 仅修改业务逻辑或 UI 文案，不涉及文件增删改名。

## 建议检查命令

```sh
scripts/check_pbxproj_mapping.py
```

自动修复可用：

```sh
scripts/check_pbxproj_mapping.py --fix
```
