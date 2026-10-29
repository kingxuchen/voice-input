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
        let titles = DeviceNaming.displayNames(for: devices)
        return devices.enumerated().map { index, device in
            let isDefault = device.id == defaultDeviceID
            let prefix = isDefault ? defaultPrefix : plainPrefix
            return MenuItem(id: device.id, title: prefix + titles[index])
        }
    }
}
