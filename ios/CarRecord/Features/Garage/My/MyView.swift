import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// “我的”页：集中放置车辆管理、项目管理入口和数据重置入口。
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
    @State var operationErrorMessage = ""
    @State var isOperationErrorAlertPresented = false
    @State var isManualNowEnabled = AppDateContext.isManualNowEnabled()
    @State var manualNowDate = AppDateContext.manualNowDate()
    @State var draftManualNowDate = AppDateContext.manualNowDate()
    @State var isManualNowPickerPresented = false

    var body: some View {
        List {
            Section("车辆管理") {
                if cars.isEmpty {
                    Text("还没有车辆，点击下方“添加车辆”开始记录。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cars) { car in
                        let isApplied = isAppliedCar(car)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(CarDisplayFormatter.name(car))
                                .font(.headline)

                            Text("上路日期：\(AppDateContext.formatShortDate(car.purchaseDate))")
                                .foregroundStyle(.secondary)
                            Text("车龄：\(CarAgeFormatter.yearsText(from: car.purchaseDate, now: AppDateContext.now())) 年")
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
                            Button(role: .destructive) {
                                deleteCar(car)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                applyCar(car)
                            } label: {
                                Label(isApplied ? "已应用" : "应用", systemImage: "checkmark.circle")
                            }
                            .tint(.blue)
                            .disabled(isApplied)

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

            Section("时间临时设置") {
                Toggle("不取系统时间，改为手动日期", isOn: $isManualNowEnabled)
                    .onChange(of: isManualNowEnabled) { _, newValue in
                        AppDateContext.setManualNowEnabled(newValue)
                    }

                if isManualNowEnabled {
                    Button {
                        draftManualNowDate = manualNowDate
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

            Section("关于") {
                HStack {
                    Text("版本号")
                    Spacer()
                    Text(appVersionText)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("我的")
        .sheet(item: $activeCarForm) { target in
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
                draftDate: $draftManualNowDate,
                currentDate: manualNowDate,
                onApply: { newValue in
                    manualNowDate = newValue
                    AppDateContext.setManualNowDate(newValue)
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
        .alert("确认重置数据？", isPresented: $isResetAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("确认重置", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("将清空车辆、保养记录和全部保养项目，且无法恢复。")
        }
        .alert("确认恢复数据？", isPresented: $isRestoreConfirmAlertPresented) {
            Button("取消", role: .cancel) {}
            Button("确认恢复", role: .destructive) {
                isImportingMaintenanceData = true
            }
        } message: {
            Text("恢复会先清空当前全部数据，再导入备份文件。")
        }
        .alert("备份恢复结果", isPresented: $isTransferResultAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(transferResultMessage)
        }
        .alert("操作失败", isPresented: $isOperationErrorAlertPresented) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(operationErrorMessage)
        }
        .onAppear {
            syncAppliedCarSelection()
            isManualNowEnabled = AppDateContext.isManualNowEnabled()
            manualNowDate = AppDateContext.manualNowDate()
            draftManualNowDate = manualNowDate
        }
        .onChange(of: cars.map(\.id)) { _, _ in
            syncAppliedCarSelection()
        }
    }
}
