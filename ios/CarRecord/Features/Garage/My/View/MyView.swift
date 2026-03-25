import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers

/// “个人中心”页：集中放置车辆管理、项目管理入口和数据重置入口。
struct MyView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Car.purchaseDate, order: .reverse) var cars: [Car]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) var serviceRecords: [MaintenanceRecord]
    @Query(sort: \MaintenanceItemOption.createdAt, order: .forward) var serviceItemOptions: [MaintenanceItemOption]

    @StateObject private var viewModel = MyViewModel()

    var body: some View {
        List {
            Section("车辆管理") {
                if cars.isEmpty {
                    Text("还没有车辆，点击下方“添加车辆”开始记录。")
                        .foregroundStyle(.secondary)
                } else {
                    let carAgeNow = viewModel.carAgeReferenceDate
                    ForEach(cars) { car in
                        let isApplied = viewModel.isAppliedCar(car)
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
                                viewModel.requestDeleteCar(car)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            .tint(.red)

                            if !isApplied {
                                Button {
                                    viewModel.applyCar(car)
                                } label: {
                                    Label("应用", systemImage: "checkmark.circle")
                                }
                                .tint(.blue)
                            }

                            Button {
                                viewModel.openEditCarForm(car)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Button {
                    viewModel.openAddCarForm()
                } label: {
                    Label("添加车辆", systemImage: "plus")
                }
            }

            Section("数据管理") {
                Button {
                    viewModel.startBackupData()
                } label: {
                    Label("备份数据", systemImage: "square.and.arrow.up")
                }

                Button {
                    viewModel.requestRestoreData()
                } label: {
                    Label("恢复数据", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    viewModel.isResetAlertPresented = true
                } label: {
                    Label("重置全部数据", systemImage: "trash")
                }

                Text("备份按车型保存保养项目配置与车辆记录。恢复会使用备份内容覆盖当前数据，且在有数据时先二次确认再清空。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isDebugModeEnabled {
                Section("调试工具") {
                    NavigationLink {
                        AppLogConsoleView()
                    } label: {
                        Label("控制台日志", systemImage: "terminal")
                    }

                    Toggle("自定义当前日期", isOn: $viewModel.isManualNowEnabled)

                    if viewModel.isManualNowEnabled {
                        Button {
                            viewModel.isManualNowPickerPresented = true
                        } label: {
                            HStack {
                                Text("手动日期")
                                Spacer()
                                Text(AppDateContext.formatShortDate(viewModel.manualNowDate))
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
                    Text(viewModel.appVersionText)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.handleVersionTap()
                }
            }
        }
        .navigationTitle("个人中心")
        .toolbar(viewModel.activeCarForm == nil ? .visible : .hidden, for: .tabBar)
        .animation(.none, value: viewModel.activeCarForm == nil)
        .navigationDestination(item: $viewModel.activeCarForm) { target in
            switch target {
            case .add:
                AddCarView()
            case .edit(let car):
                AddCarView(editingCar: car)
            }
        }
        .sheet(isPresented: $viewModel.isManualNowPickerPresented) {
            DayDatePickerSheetView(
                title: "选择日期",
                label: "手动日期",
                currentDate: viewModel.manualNowDate,
                onApply: { newValue in
                    viewModel.applyManualNowDate(newValue)
                },
                onCancel: { viewModel.isManualNowPickerPresented = false }
            )
        }
        .fileExporter(
            isPresented: $viewModel.isExportingMaintenanceData,
            document: viewModel.exportDocument,
            contentType: .json,
            defaultFilename: viewModel.exportFilename
        ) { result in
            switch result {
            case .success(let url):
                viewModel.presentTransferResult("备份成功：\(url.lastPathComponent)")
            case .failure(let error):
                viewModel.presentTransferResult("备份失败：\(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $viewModel.isImportingMaintenanceData,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    viewModel.presentTransferResult("恢复失败：未选择文件。")
                    return
                }
                viewModel.importMaintenanceData(from: url)
            case .failure(let error):
                viewModel.presentTransferResult("恢复失败：\(error.localizedDescription)")
            }
        }
        .alert(AppAlertText.resetDataConfirmTitle, isPresented: $viewModel.isResetAlertPresented) {
            Button(AppPopupText.cancel, role: .cancel) {}
            Button(AppAlertText.confirmResetAction, role: .destructive) {
                viewModel.resetAllData()
            }
        } message: {
            Text(AppAlertText.resetDataMessage)
        }
        .alert(AppAlertText.restoreDataConfirmTitle, isPresented: $viewModel.isRestoreConfirmAlertPresented) {
            Button(AppPopupText.cancel, role: .cancel) {}
            Button(AppAlertText.confirmRestoreAction, role: .destructive) {
                viewModel.confirmRestoreData()
            }
        } message: {
            Text(AppAlertText.restoreDataMessage)
        }
        .alert(AppAlertText.deleteCarConfirmTitle, isPresented: Binding(
            get: { viewModel.pendingDeleteCar != nil },
            set: { newValue in
                if !newValue {
                    viewModel.pendingDeleteCar = nil
                }
            }
        )) {
            Button(AppPopupText.cancel, role: .cancel) {
                viewModel.pendingDeleteCar = nil
            }
            Button(AppAlertText.confirmDeleteAction, role: .destructive) {
                viewModel.confirmDeleteCar()
            }
        } message: {
            if let car = viewModel.pendingDeleteCar {
                Text(AppAlertText.deleteCarMessage(carName: CarDisplayFormatter.name(car)))
            } else {
                Text(AppAlertText.deleteCarFallbackMessage)
            }
        }
        .alert(AppAlertText.transferResultTitle, isPresented: $viewModel.isTransferResultAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(viewModel.transferResultMessage)
        }
        .alert(AppAlertText.operationFailedTitle, isPresented: $viewModel.isOperationErrorAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(viewModel.operationErrorMessage)
        }
        .alert("调试模式状态", isPresented: $viewModel.isDebugModeStatusAlertPresented) {
            Button(AppPopupText.acknowledge, role: .cancel) {}
        } message: {
            Text(viewModel.debugModeStatusMessage)
        }
        .onAppear {
            refreshViewModelContext()
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            refreshViewModelContext()
        }
        .onChange(of: serviceRecords.map(\.id)) { _, _ in
            refreshViewModelContext()
        }
        .onChange(of: serviceItemOptions.map(\.id)) { _, _ in
            refreshViewModelContext()
        }
    }

    private func refreshViewModelContext() {
        viewModel.refreshContext(
            modelContext: modelContext,
            cars: cars,
            serviceRecords: serviceRecords,
            serviceItemOptions: serviceItemOptions
        )
    }
}

struct AppLogConsoleView: View {
    @StateObject private var viewModel = AppLogConsoleViewModel()

    var body: some View {
        List {
            if viewModel.logFilePath.isEmpty == false {
                Text("日志文件：\(viewModel.logFilePath)（\(viewModel.formattedFileSize)）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.logContent.isEmpty {
                Text("暂无日志输出。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.parsedLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(viewModel.color(for: line))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("控制台日志")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("清空") {
                    Task {
                        await viewModel.clearAndReload()
                    }
                }
                .disabled(viewModel.logContent.isEmpty)
            }
        }
        .task {
            await viewModel.reloadLogFile()
        }
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { _ in
            Task {
                await viewModel.reloadLogFile()
            }
        }
    }
}
