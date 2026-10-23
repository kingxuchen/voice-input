import Testing
import CoreAudio
@testable import VoiceInputCore

/// 可控的 provider 替身：可注入设备列表、默认设备、切换返回值，并可主动触发属性变更事件。
@MainActor
final class FakeAudioDeviceProvider: AudioDeviceProviding {
    var devices: [AudioDevice] = []
    var defaultID: AudioDeviceID?
    var setDefaultStatus: OSStatus = noErr
    private(set) var setDefaultCalls: [AudioDeviceID] = []
    private(set) var deviceReadCount = 0
    private var handler: (() -> Void)?

    func inputDevices() -> [AudioDevice] {
        deviceReadCount += 1
        return devices
    }

    func defaultInputDeviceID() -> AudioDeviceID? { defaultID }

    func setDefaultInputDevice(id: AudioDeviceID) -> OSStatus {
        setDefaultCalls.append(id)
        if setDefaultStatus == noErr { defaultID = id }
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
