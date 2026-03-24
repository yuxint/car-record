import Foundation

extension CoreConfig {
    /// 过滤禁用项目：默认仅保留启用项目；可按需包含禁用项目。
    static func filterDisabledOptions(
        _ options: [MaintenanceItemOption],
        disabledItemIDsRaw: String,
        includeDisabled: Bool
    ) -> [MaintenanceItemOption] {
        guard includeDisabled == false else { return options }
        let disabledItemIDs = Set(parseItemIDs(disabledItemIDsRaw))
        guard disabledItemIDs.isEmpty == false else { return options }
        return options.filter { disabledItemIDs.contains($0.id) == false }
    }
}
