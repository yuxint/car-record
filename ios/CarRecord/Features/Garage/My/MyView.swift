import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers
import UIKit

/// “个人中心”页：集中放置车辆管理、项目管理入口和数据重置入口。
struct MyView: View {
    @Environment(\.modelContext) var modelContext 
    @Query(sort: \Car.purchaseDate, order: .reverse) var cars: [Car] 
    @Query(sort: \MaintenanceRecord.date, order: .reverse) var serviceRecords: [MaintenanceRecord] 
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) var serviceItemOptions: [MaintenanceItemOption]
    @AppStorage(AppliedCarContext.storageKey) var appliedCarIDRaw = ""

    @State var activeCarForm: CarFormTarget?
    @State var isResetAlertPresented = false
    @State var isImportingMaintenanceData = false
    @State var isExportingMaintenanceData = false
    @State var exportDocument = MyDataTransferDocument(data: Data())
    @State var exportFilename = "car-record-maintenance"
    @State var transferResultMessage = ""
    @State var isTransferResultAlertPresented = false
    @State var isRestoreConfirmAlertPresented = false
    @State var pendingDeleteCar: Car?
    @State var operationErrorMessage = ""
    @State var isOperationErrorAlertPresented = false
    @AppStorage(AppDateContext.useManualNowStorageKey) var isManualNowEnabled = false
    @AppStorage(AppDateContext.manualNowTimestampStorageKey) var manualNowTimestamp = 0.0
    @AppStorage("app_debug_mode_enabled") var isDebugModeEnabled = false
    @State var isManualNowPickerPresented = false
    @State var versionTapCount = 0
    @State var lastVersionTapAt: Date?
    @State var debugModeStatusMessage = ""
    @State var isDebugModeStatusAlertPresented = false

    var body: some View {
        List {
            Section("车辆管理") {
                if cars.isEmpty {
                    Text("还没有车辆，点击下方“添加车辆”开始记录。")
                        .foregroundStyle(.secondary)
                } else {
                    let carAgeNow = isManualNowEnabled ? manualNowDate : Date()
                    ForEach(cars) { car in
                        let isApplied = isAppliedCar(car)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(CarDisplayFormatter.name(car))
                                .font(.headline)

                            Text("上路日期：\(AppDateContext.formatShortDate(car.purchaseDate))")
                                .foregroundStyle(.secondary)
                            Text("车龄：\(CarAgeFormatter.yearsText(from: car.purchaseDate, now: carAgeNow)) 年")
                                .foregroundStyle(.secondary)
                            Text("里程：\(car.mileage) km")
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            (isApplied ? Color.blue.opacity(0.08) : Color(.secondarySystemBackground)),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    isApplied ? Color.blue.opacity(0.35) : Color(.separator),
                                    lineWidth: 1
                                )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                pendingDeleteCar = car
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            .tint(.red)

                            if !isApplied {
                                Button {
                                    applyCar(car)
                                } label: {
                                    Label("应用", systemImage: "checkmark.circle")
                                }
                                .tint(.blue)
                            }

                            Button {
                                openEditCarForm(car)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Button {
                    openAddCarForm()
                } label: {
                    Label("添加车辆", systemImage: "plus")
                }
            }

            Section("数据管理") {
                Button {
                    startBackupData()
                } label: {
                    Label("备份数据", systemImage: "square.and.arrow.up")
                }

                Button {
                    if hasAnyBusinessData {
                        isRestoreConfirmAlertPresented = true
                    } else {
                        isImportingMaintenanceData = true
                    }
                } label: {
                    Label("恢复数据", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    isResetAlertPresented = true
                } label: {
                    Label("重置全部数据", systemImage: "trash")
                }

                Text("备份按车型保存保养项目配置与车辆记录。恢复会使用备份内容覆盖当前数据，且在有数据时先二次确认再清空。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isDebugModeEnabled {
                Section("调试工具") {
                    NavigationLink {
                        AppLogConsoleView()
                    } label: {
                        Label("控制台日志", systemImage: "terminal")
                    }

                    Toggle("自定义当前日期", isOn: $isManualNowEnabled)
                        .onChange(of: isManualNowEnabled) { _, newValue in
                            AppDateContext.setManualNowEnabled(newValue)
                        }

                    if isManualNowEnabled {
                        Button {
                            isManualNowPickerPresented = true
                        } label: {
                            HStack {
                                Text("手动日期")
                                Spacer()
                                Text(AppDateContext.formatShortDate(manualNowDate))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("仅影响本地“当前日期”计算（如车龄、提醒进度、今日里程同步），不会修改历史记录日期。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("关于") {
                HStack {
                    Text("版本号")
                    Spacer()
                    Text(appVersionText)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    handleVersionTap()
                }
            }
        }
        .navigationTitle("个人中心")
        .toolbar(activeCarForm == nil ? .visible : .hidden, for: .tabBar)
        .animation(.none, value: activeCarForm == nil)
        .navigationDestination(item: $activeCarForm) { target in
            switch target {
            case .add:
                AddCarView()
            case .edit(let car):
                AddCarView(editingCar: car)
            }
        }
        .sheet(isPresented: $isManualNowPickerPresented) {
            DayDatePickerSheetView(
                title: "选择日期",
                label: "手动日期",
                currentDate: manualNowDate,
                onApply: { newValue in
                    AppDateContext.setManualNowDate(newValue)
                    manualNowTimestamp = AppDateContext.calendar.startOfDay(for: newValue).timeIntervalSince1970
                    isManualNowPickerPresented = false
                },
                onCancel: { isManualNowPickerPresented = false }
            )
        }
        .fileExporter(
            isPresented: $isExportingMaintenanceData,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success(let url):
                presentTransferResult("备份成功：\(url.lastPathComponent)")
            case .failure(let error):
                presentTransferResult("备份失败：\(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $isImportingMaintenanceData,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    presentTransferResult("恢复失败：未选择文件。")
                    return
                }
                importMaintenanceData(from: url)
            case .failure(let error):
                presentTransferResult("恢复失败：\(error.localizedDescription)")
            }
        }
        .alert(AppAlertText.resetDataConfirmTitle, isPresented: $isResetAlertPresented) {
            Button(AppPopupText.cancel, role: .cancel) {}
            Button(AppAlertText.confirmResetAction, role: .destructive) {
                resetAllData()
            }
        } message: {
            Text(AppAlertText.resetDataMessage)
        }
        .alert(AppAlertText.restoreDataConfirmTitle, isPresented: $isRestoreConfirmAlertPresented) {
            Button(AppPopupText.cancel, role: .cancel) {}
            Button(AppAlertText.confirmRestoreAction, role: .destructive) {
                isImportingMaintenanceData = true
            }
        } message: {
            Text(AppAlertText.restoreDataMessage)
        }
        .alert(AppAlertText.deleteCarConfirmTitle, isPresented: Binding(
            get: { pendingDeleteCar != nil },
            set: { newValue in
                if !newValue {
                    pendingDeleteCar = nil
                }
            }
        )) {
            Button(AppPopupText.cancel, role: .cancel) {
                pendingDeleteCar = nil
            }
            Button(AppAlertText.confirmDeleteAction, role: .destructive) {
                guard let car = pendingDeleteCar else { return }
                pendingDeleteCar = nil
                deleteCar(car)
            }
        } message: {
            if let car = pendingDeleteCar {
                Text(AppAlertText.deleteCarMessage(carName: CarDisplayFormatter.name(car)))
            } else {
                Text(AppAlertText.deleteCarFallbackMessage)
            }
        }
        .alert(AppAlertText.transferResultTitle, isPresented: $isTransferResultAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(transferResultMessage)
        }
        .alert(AppAlertText.operationFailedTitle, isPresented: $isOperationErrorAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
        .alert("调试模式状态", isPresented: $isDebugModeStatusAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(debugModeStatusMessage)
        }
        .onAppear {
            syncAppliedCarSelection()
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            syncAppliedCarSelection()
        }
    }

    var manualNowDate: Date {
        guard manualNowTimestamp > 0 else {
            return AppDateContext.calendar.startOfDay(for: Date())
        }
        let storedDate = Date(timeIntervalSince1970: manualNowTimestamp)
        return AppDateContext.calendar.startOfDay(for: storedDate)
    }

    func handleVersionTap() {
        let now = Date()
        if let lastVersionTapAt, now.timeIntervalSince(lastVersionTapAt) > 1.2 {
            versionTapCount = 0
        }
        versionTapCount += 1
        lastVersionTapAt = now

        if versionTapCount >= 5 {
            versionTapCount = 0
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
}

struct AppLogConsoleView: View {
    @State var isCopiedAlertPresented = false
    @State var logFilePath = ""
    @State var logContent = ""

    var body: some View {
        List {
            if logFilePath.isEmpty == false {
                Text("日志文件：\(logFilePath)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if logContent.isEmpty {
                Text("暂无日志输出。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(parsedLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(color(for: line))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("控制台日志")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("清空") {
                    Task {
                        await AppLogFileStore.shared.clear()
                        await reloadLogFile()
                    }
                }
                .disabled(logContent.isEmpty)

                Button("复制") {
                    UIPasteboard.general.string = logContent
                    isCopiedAlertPresented = true
                }
                .disabled(logContent.isEmpty)
            }
        }
        .task {
            await reloadLogFile()
        }
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { _ in
            Task {
                await reloadLogFile()
            }
        }
        .alert("已复制日志", isPresented: $isCopiedAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text("日志内容已复制到剪贴板。")
        }
    }

    var parsedLines: [String] {
        logContent
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    func reloadLogFile() async {
        let path = await AppLogFileStore.shared.filePath()
        let content = await AppLogFileStore.shared.readAll()
        await MainActor.run {
            logFilePath = path
            logContent = content
        }
    }

    func color(for line: String) -> Color {
        if line.contains("[ERROR]") {
            return .red
        }
        if line.contains("[WARN]") {
            return .yellow
        }
        if line.contains("[INFO]") {
            return .black
        }
        return .primary
    }
}
