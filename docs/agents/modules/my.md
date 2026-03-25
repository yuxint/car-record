# My 模块最小上下文

## 必读

- `ios/CarRecord/Features/Garage/My/View/MyView.swift`
- `ios/CarRecord/Features/Garage/My/ViewModel/MyViewModel.swift`
- `ios/CarRecord/Features/Garage/My/ViewModel/MyViewModelCarActions.swift`
- `ios/CarRecord/Features/Garage/My/ViewModel/MyViewModelBackup.swift`
- `ios/CarRecord/Features/Garage/My/ViewModel/MyViewModelRestore.swift`

## 仅当以下改动才读

- 改备份恢复结构：补读 `docs/agents/data-model.md` 与 `docs/agents/scripts-reference.md`，并看 `MyDataTransfer.swift`。
- 改重置清空逻辑：看 `MyViewModelRestoreCleanup.swift`。
- 改应用车型或跨页跳转：补读 `docs/agents/runtime-contexts.md`。

## 改完自检 3 条

- 恢复流程是否仍“先清空再导入”且可回滚。
- `MyDataTransferPayload` 改动是否同步脚本。
- 删除车辆后应用车型是否正确回退。
