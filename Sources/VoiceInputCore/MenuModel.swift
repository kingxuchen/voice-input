import CoreAudio

public struct MenuItem: Identifiable, Equatable, Sendable {
    public let id: AudioDeviceID
    public let title: String

    public init(id: AudioDeviceID, title: String) {
        self.id = id
        self.title = title
    }
}

public enum MenuModel {
    public static let defaultPrefix = "✓  "
    public static let plainPrefix = "    "

    public static func deviceItems(devices: [AudioDevice], defaultDeviceID: AudioDeviceID?) -> [MenuItem] {
        let titles = displayNames(for: devices)
        return devices.enumerated().map { index, device in
            let isDefault = device.id == defaultDeviceID
            let prefix = isDefault ? defaultPrefix : plainPrefix
            return MenuItem(id: device.id, title: prefix + titles[index])
        }
    }

    /// 同名设备按 HAL 出现次序追加序号：第一个原名，第二个 " 2"，第三个 " 3"。
    /// 若真实设备名本身已占用该带号名字，则继续跳号，避免菜单里出现两条同名条目。
    static func displayNames(for devices: [AudioDevice]) -> [String] {
        var used = Set(devices.map(\.name))
        var occurrences: [String: Int] = [:]
        var result: [String] = []
        result.reserveCapacity(devices.count)

        for device in devices {
            let occurrence = (occurrences[device.name] ?? 0) + 1
            occurrences[device.name] = occurrence

            guard occurrence > 1 else {
                result.append(device.name)
                continue
            }
            var suffix = occurrence
            var candidate = "\(device.name) \(suffix)"
            while used.contains(candidate) {
                suffix += 1
                candidate = "\(device.name) \(suffix)"
            }
            used.insert(candidate)
            result.append(candidate)
        }
        return result
    }
}
