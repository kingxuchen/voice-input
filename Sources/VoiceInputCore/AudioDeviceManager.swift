import CoreAudio
import Observation

@Observable
@MainActor
public final class AudioDeviceManager {
    public private(set) var devices: [AudioDevice]
    public private(set) var defaultDeviceID: AudioDeviceID?

    private let provider: any AudioDeviceProviding
    private let debounceInterval: Duration
    private var refreshTask: Task<Void, Never>?

    public init(
        provider: any AudioDeviceProviding,
        debounceInterval: Duration = .milliseconds(50)
    ) {
        self.provider = provider
        self.debounceInterval = debounceInterval
        self.devices = provider.inputDevices()
        self.defaultDeviceID = provider.defaultInputDeviceID()

        _ = provider.addListener { [weak self] in
            Task { @MainActor in self?.scheduleRefresh() }
        }
    }

    isolated deinit {
        refreshTask?.cancel()
        provider.removeListener()
    }

    public var menuItems: [MenuItem] {
        MenuModel.deviceItems(devices: devices, defaultDeviceID: defaultDeviceID)
    }

    /// 重读系统真实状态：设备列表与当前默认输入。
    ///
    /// 菜单每次打开都会调用（见 `MenuOpenObserver`），保证展示的是最新音源。
    public func refresh() {
        devices = provider.inputDevices()
        defaultDeviceID = provider.defaultInputDeviceID()
    }

    public func select(deviceID: AudioDeviceID) {
        _ = provider.setDefaultInputDevice(id: deviceID)
        defaultDeviceID = provider.defaultInputDeviceID()
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
}
