# Xcode 项目文件更新规则

当“文件清单或路径”变化时，需要检查并更新 `CarRecord/CarRecord.xcodeproj/project.pbxproj`，运行前请与用户确认代码是否调整完成。

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

## 执行建议

- 优先在仓库根目录执行脚本，避免相对路径误判。
- 执行 `--fix` 后，至少复查新增/删除文件对应的 `PBXFileReference` 与 `PBXSourcesBuildPhase` 结果是否符合预期。
