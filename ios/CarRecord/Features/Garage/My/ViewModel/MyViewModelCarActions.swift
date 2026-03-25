import SwiftUI
import SwiftData

extension MyViewModel {
    func deleteCars(at offsets: IndexSet) {
        guard let modelContext = requiredModelContext() else { return }
        let cars = dataSnapshot.cars
        let serviceItemOptions = dataSnapshot.serviceItemOptions
        let deletedIDs = Set(offsets.compactMap { cars.indices.contains($0) ? cars[$0].id : nil })
        for index in offsets {
            modelContext.deleteWithAudit(cars[index])
        }
        for option in serviceItemOptions where option.ownerCarID.flatMap({ deletedIDs.contains($0) }) == true {
            modelContext.deleteWithAudit(option)
        }
        if let message = modelContext.saveOrLog("删除车辆") {
            operationErrorMessage = message
            isOperationErrorAlertPresented = true
            return
        }
        if let appliedCarID = AppliedCarContext.decodeCarID(from: appliedCarIDRaw),
           deletedIDs.contains(appliedCarID) {
            syncAppliedCarSelection()
        }
    }

    /// 打开新增车辆表单。
    func openAddCarForm() {
        activeCarForm = .add
    }

    /// 打开编辑车辆表单。
    func openEditCarForm(_ car: Car) {
        activeCarForm = .edit(car)
    }

    /// 左滑删除单车：与批量删除逻辑保持一致的保存与报错处理。
    func deleteCar(_ car: Car) {
        let cars = dataSnapshot.cars
        guard let index = cars.firstIndex(where: { $0.id == car.id }) else { return }
        deleteCars(at: IndexSet(integer: index))
    }

    /// 应用车型：保养提醒页与保养记录页会按该车型隔离读取/写入数据。
    func applyCar(_ car: Car) {
        appliedCarIDRaw = AppliedCarContext.encodeCarID(car.id)
    }

    /// 判断车辆是否为当前已应用车型。
    func isAppliedCar(_ car: Car) -> Bool {
        AppliedCarContext.decodeCarID(from: appliedCarIDRaw) == car.id
    }

    /// 清空所有业务数据，重置为初始状态。
    func resetAllData() {
        let cars = dataSnapshot.cars
        let serviceRecords = dataSnapshot.serviceRecords
        let serviceItemOptions = dataSnapshot.serviceItemOptions
        AppLogger.info(
            "开始重置全部数据",
            payload: "cars=\(cars.count), records=\(serviceRecords.count), items=\(serviceItemOptions.count)"
        )
        do {
            try clearAllBusinessData()
            AppLogger.info("重置全部数据成功")
        } catch {
            AppLogger.error("重置数据失败", payload: error.localizedDescription)
            operationErrorMessage = "重置数据失败，请稍后重试。"
            isOperationErrorAlertPresented = true
        }
    }

    /// 导出当前全部车辆及其关联保养数据，作为本地备份文件。

}
