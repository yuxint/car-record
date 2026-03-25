# 运行时上下文

## 日期上下文

- 入口：`ios/CarRecord/Core/AppDateContext.swift`
- 禁止事项：不要散落 `Date()` 作为业务“现在”。
- 常见坑：手动日期开关打开时，所有“今天”逻辑都要跟随 `now()`。

## 应用车型上下文

- 入口：`ios/CarRecord/Core/AppliedCarContext.swift`
- 存储键：`applied_car_id`
- 禁止事项：不要直接写原始 ID 字符串绕过上下文方法。
- 常见坑：持久化 ID 失效时，必须允许回退到第一辆车。

## 跨 Tab 导航上下文

- 入口：`ios/CarRecord/Core/AppliedCarContext.swift`（同文件内 `AppNavigationContext`）
- 存储键：`root_tab_navigation_target`、`root_tab_navigation_nonce`
- 禁止事项：不要绕过 `requestNavigation(to:)` 直接改 RootTab 状态。
- 常见坑：目标 Tab 切换后要保证根层级刷新逻辑不丢。
