import CoreAudio

/// 设备显示名的领域规则（不属于菜单，也不属于 CLI 协议）。
///
/// 同名设备按 HAL 出现次序追加序号：第一个原名，第二个 " 2"，第三个 " 3"；
/// 若某个真实设备名本身就占用了该带号名字，则继续跳号，避免列表里出现两条同名条目。
///
/// 菜单和 `voiceinput-cli` 的 `displayName` 都必须给出同一份名字——规则只此一处，
/// 谁都不许自己再实现一遍，否则同一台设备在菜单里的叫法会和插件里的叫法对不上。
enum DeviceNaming {
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
