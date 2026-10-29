import CoreAudio
import OSLog
import Observation

/// 菜单层的设备状态：一次 HAL 快照，要么整体读到，要么整体读不到。
///
/// 以前 `devices` 与 `defaultDeviceID` 是两个各自赋值的属性，任何一次读失败都会留下
/// 「看起来正常的空列表 + 没有默认」——界面只能把「读不到」说成「没有设备」。
/// 现在快照要么整体成立，要么整体是 `.unreadable`，这句谎话在类型上就写不出来。
public enum DeviceListState: Equatable, Sendable {
    /// 读到了。`devices` 可以是空数组：这台机器确实一台输入设备都没有。
    case devices([AudioDevice], defaultID: AudioDeviceID?)
    /// 读不到：界面只能说「无法读取」，不能冒充空列表。
    case unreadable(HALReadFailure)
}

@Observable
@MainActor
public final class AudioDeviceManager {
    public private(set) var state: DeviceListState

    private let provider: any AudioDeviceProviding
    private let debounceInterval: Duration
    private var refreshTask: Task<Void, Never>?

    public init(
        provider: any AudioDeviceProviding,
        debounceInterval: Duration = .milliseconds(50)
    ) {
        self.provider = provider
        self.debounceInterval = debounceInterval
        self.state = Self.snapshot(from: provider)

        let subscribed = provider.addListener { [weak self] in
            Task { @MainActor in self?.scheduleRefresh() }
        }
        if !subscribed {
            // 订阅失败不是致命错误：菜单每次打开仍会重读。但也别假装没事——
            // 用户插拔设备后菜单会停在旧列表，控制台得能查到原因。
            Self.logger.error("订阅设备变更通知失败：菜单不会随设备插拔自动刷新，只在打开时重读")
        }
    }

    isolated deinit {
        refreshTask?.cancel()
        provider.removeListener()
    }

    /// 读不到时是空数组（界面据此不列条目）；要区分「空」和「读不到」，看 `state`。
    public var menuItems: [MenuItem] {
        guard case let .devices(devices, defaultID) = state else { return [] }
        return MenuModel.deviceItems(devices: devices, defaultDeviceID: defaultID)
    }

    /// 重读系统真实状态：设备列表与当前默认输入。
    ///
    /// 菜单每次打开都会调用（见 `AppState`），保证展示的是最新音源。
    public func refresh() {
        state = Self.snapshot(from: provider)
    }

    /// 切换默认输入。写入结果按 0004 #3 静默处理：不弹错误提示，
    /// 勾选永远对齐系统回读出来的真实默认（系统可能拒绝、回落或另有变化）。
    ///
    /// 「静默」指不对用户报错，不是把 OSStatus 扔掉：写失败后紧跟的这次回读会把勾选
    /// 放回系统真实默认，用户看到的是真相而不是一个撒谎的勾；失败原因只进日志。
    public func select(deviceID: AudioDeviceID) {
        let status = provider.setDefaultInputDevice(id: deviceID)
        if status != noErr {
            Self.logger.error(
                "切换默认输入失败 device \(deviceID)（OSStatus \(status)），重新回读系统状态"
            )
        }
        state = Self.snapshot(from: provider)
    }

    private func scheduleRefresh() {
        let interval = debounceInterval
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled, let self else { return }
            self.refresh()
        }
    }

    /// 列表与默认必须出自同一次快照：分开赋值就会留下「新列表 + 旧勾选」的半成品状态。
    /// 任一读取抛错都整份作废，而不是各自退化成空值。
    private static func snapshot(from provider: any AudioDeviceProviding) -> DeviceListState {
        do {
            let devices = try provider.inputDevices()
            let defaultID = try provider.defaultInputDeviceID()
            return .devices(devices, defaultID: defaultID)
        } catch {
            return .unreadable(error)
        }
    }

    private static let logger = AppIdentity.logger(category: "AudioDevice")
}
