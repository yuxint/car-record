import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class MyViewModel: ObservableObject {
    @Published var activeCarForm: CarFormTarget?
    @Published var isResetAlertPresented = false
    @Published var isImportingMaintenanceData = false
    @Published var isExportingMaintenanceData = false
    @Published var exportDocument = MyDataTransferDocument(data: Data())
    @Published var exportFilename = "car-record-maintenance"
    @Published var transferResultMessage = ""
    @Published var isTransferResultAlertPresented = false
    @Published var isRestoreConfirmAlertPresented = false
    @Published var pendingDeleteCar: Car?
    @Published var operationErrorMessage = ""
    @Published var isOperationErrorAlertPresented = false
    @Published var isManualNowEnabled = false {
        didSet {
            UserDefaults.standard.set(isManualNowEnabled, forKey: AppDateContext.useManualNowStorageKey)
            AppDateContext.setManualNowEnabled(isManualNowEnabled)
        }
    }
    @Published var manualNowTimestamp = 0.0 {
        didSet {
            UserDefaults.standard.set(manualNowTimestamp, forKey: AppDateContext.manualNowTimestampStorageKey)
        }
    }
    @Published var isDebugModeEnabled = false {
        didSet {
            UserDefaults.standard.set(isDebugModeEnabled, forKey: Self.debugModeStorageKey)
        }
    }
    @Published var isManualNowPickerPresented = false
    @Published var debugModeStatusMessage = ""
    @Published var isDebugModeStatusAlertPresented = false

    @Published var appliedCarIDRaw = "" {
        didSet {
            UserDefaults.standard.set(appliedCarIDRaw, forKey: AppliedCarContext.storageKey)
        }
    }

    private(set) var dataSnapshot = MyBusinessDataSnapshot()
    var modelContext: ModelContext?
    private var debugTapState = MyDebugTapState()

    private static let debugModeStorageKey = "app_debug_mode_enabled"

    init() {
        appliedCarIDRaw = UserDefaults.standard.string(forKey: AppliedCarContext.storageKey) ?? ""
        isManualNowEnabled = UserDefaults.standard.bool(forKey: AppDateContext.useManualNowStorageKey)
        manualNowTimestamp = UserDefaults.standard.double(forKey: AppDateContext.manualNowTimestampStorageKey)
        isDebugModeEnabled = UserDefaults.standard.bool(forKey: Self.debugModeStorageKey)
        AppDateContext.setManualNowEnabled(isManualNowEnabled)
    }

    var manualNowDate: Date {
        guard manualNowTimestamp > 0 else {
            return AppDateContext.calendar.startOfDay(for: Date())
        }
        let storedDate = Date(timeIntervalSince1970: manualNowTimestamp)
        return AppDateContext.calendar.startOfDay(for: storedDate)
    }

    var carAgeReferenceDate: Date {
        isManualNowEnabled ? manualNowDate : Date()
    }

    func refreshContext(
        modelContext: ModelContext,
        cars: [Car],
        serviceRecords: [MaintenanceRecord],
        serviceItemOptions: [MaintenanceItemOption]
    ) {
        self.modelContext = modelContext
        dataSnapshot = MyBusinessDataSnapshot(
            cars: cars,
            serviceRecords: serviceRecords,
            serviceItemOptions: serviceItemOptions
        )
        syncAppliedCarSelection()
    }

    func requestDeleteCar(_ car: Car) {
        pendingDeleteCar = car
    }

    func confirmDeleteCar() {
        guard let car = pendingDeleteCar else { return }
        pendingDeleteCar = nil
        deleteCar(car)
    }

    func requestRestoreData() {
        if hasAnyBusinessData {
            isRestoreConfirmAlertPresented = true
        } else {
            isImportingMaintenanceData = true
        }
    }

    func confirmRestoreData() {
        isImportingMaintenanceData = true
    }

    func applyManualNowDate(_ newValue: Date) {
        AppDateContext.setManualNowDate(newValue)
        manualNowTimestamp = AppDateContext.calendar.startOfDay(for: newValue).timeIntervalSince1970
        isManualNowPickerPresented = false
    }

    func handleVersionTap() {
        let now = Date()
        if let lastVersionTapAt = debugTapState.lastVersionTapAt,
           now.timeIntervalSince(lastVersionTapAt) > 1.2 {
            debugTapState.versionTapCount = 0
        }
        debugTapState.versionTapCount += 1
        debugTapState.lastVersionTapAt = now

        if debugTapState.versionTapCount >= 5 {
            debugTapState.versionTapCount = 0
            isDebugModeEnabled.toggle()
            if isDebugModeEnabled {
                AppLogger.info("调试模式已开启")
                debugModeStatusMessage = "调试模式已开启，现在可以使用“调试工具”中的时间临时设置和控制台日志。"
            } else {
                AppLogger.info("调试模式已关闭")
                debugModeStatusMessage = "调试模式已关闭。"
            }
            isDebugModeStatusAlertPresented = true
        }
    }

    func requiredModelContext() -> ModelContext? {
        guard let modelContext else {
            operationErrorMessage = "操作失败：上下文未初始化。"
            isOperationErrorAlertPresented = true
            return nil
        }
        return modelContext
    }
}
