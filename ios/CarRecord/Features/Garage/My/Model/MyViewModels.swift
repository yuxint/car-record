import Foundation
import SwiftData

struct MyBusinessDataSnapshot {
    var cars: [Car] = []
    var serviceRecords: [MaintenanceRecord] = []
    var serviceItemOptions: [MaintenanceItemOption] = []
}

struct MyDebugTapState {
    var versionTapCount = 0
    var lastVersionTapAt: Date?
}
