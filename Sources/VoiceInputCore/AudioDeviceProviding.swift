import CoreAudio

/// 唯一测试接缝：隔离 Core Audio HAL。
///
/// 协议标注 `@MainActor`：调用方 `AudioDeviceManager` 与全部 UI 均在主线程，
/// 而 Swift 6 下 `@MainActor` 类型无法满足 nonisolated 协议需求
/// （#ConformanceIsolation）。方法签名与 SPEC 0006 逐字一致。
@MainActor
public protocol AudioDeviceProviding {
    /// 含输入流的设备，按 HAL 返回顺序，名称为系统原文
    func inputDevices() -> [AudioDevice]
    func defaultInputDeviceID() -> AudioDeviceID?
    func setDefaultInputDevice(id: AudioDeviceID) -> OSStatus
    func addListener(_ handler: @escaping () -> Void) -> Bool
    func removeListener()
}
