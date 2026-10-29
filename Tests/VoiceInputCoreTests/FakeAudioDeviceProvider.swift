import Testing
import CoreAudio
@testable import VoiceInputCore

/// 可控的 provider 替身：可注入设备列表、默认设备、读取失败、切换返回值，并可主动触发属性变更事件。
@MainActor
final class FakeAudioDeviceProvider: AudioDeviceProviding {
    var devices: [AudioDevice] = []
    var defaultID: AudioDeviceID?
    /// 注入读失败：非 nil 时对应读取抛 `HALReadFailure`。
    /// 有了它，「HAL 报错」与「HAL 答没有」才能在测试里分成两条不同的路径来断言。
    var devicesFailure: HALReadFailure?
    var defaultFailure: HALReadFailure?
    var setDefaultStatus: OSStatus = noErr
    /// 模拟「写入成功但随后读不回默认设备」：默认输入读取返回 nil。
    var clearDefaultAfterWrite = false
    /// 模拟「写入成功，但紧接着 HAL 读不到」：置上后，写入完成即让后续读取开始抛错。
    var readFailureAfterWrite: HALReadFailure?
    private(set) var setDefaultCalls: [AudioDeviceID] = []
    private(set) var deviceReadCount = 0
    private var handler: (() -> Void)?

    func inputDevices() throws(HALReadFailure) -> [AudioDevice] {
        deviceReadCount += 1
        if let devicesFailure { throw devicesFailure }
        return devices
    }

    func defaultInputDeviceID() throws(HALReadFailure) -> AudioDeviceID? {
        if let defaultFailure { throw defaultFailure }
        return defaultID
    }

    func setDefaultInputDevice(id: AudioDeviceID) -> OSStatus {
        setDefaultCalls.append(id)
        if setDefaultStatus == noErr {
            defaultID = clearDefaultAfterWrite ? nil : id
            // 只在显式配置时改变读失败状态：写成功不该悄悄清掉调用方事先注入的故障。
            if let readFailureAfterWrite { devicesFailure = readFailureAfterWrite }
        }
        return setDefaultStatus
    }

    func addListener(_ handler: @escaping () -> Void) -> Bool {
        self.handler = handler
        return true
    }

    func removeListener() { handler = nil }

    func fireChanged() { handler?() }
}

/// 本机常见三台输入设备，供各测试复用。
@MainActor
func makeStandardProvider() -> FakeAudioDeviceProvider {
    let provider = FakeAudioDeviceProvider()
    provider.devices = [
        AudioDevice(id: 177, name: "vRemoteDr 2ch"),
        AudioDevice(id: 93, name: "MacBook Pro麦克风"),
        AudioDevice(id: 115, name: "BlackHole 2ch"),
    ]
    provider.defaultID = 177
    return provider
}

/// 一处 HAL 读失败的样例值，供各测试复用（选择子取设备枚举属性，状态码取 -50 参数错误）。
let sampleReadFailure = HALReadFailure(selector: kAudioHardwarePropertyDevices, status: -50)

/// 轮询等待条件成立，避免固定 sleep 在并行测试负载下过紧。
@MainActor
func eventually(
    timeout: Duration = .seconds(3),
    _ condition: @MainActor () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
