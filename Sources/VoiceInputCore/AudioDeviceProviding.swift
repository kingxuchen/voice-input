import CoreAudio

/// HAL 读取失败：带上是哪个属性、HAL 回了什么状态码。
///
/// 存在的唯一理由，是把「读不到」从「没有」里分出来：
/// HAL 报错是失败；HAL 答「一台设备都没有」是一个正常的空数组。
/// 这两件事在界面上该说不同的话（「无法读取音频设备」vs「未发现可用输入设备」），
/// 所以不能再像以前那样都收敛成 `[]`。
public struct HALReadFailure: Error, Equatable, Sendable {
    public let selector: AudioObjectPropertySelector
    public let status: OSStatus

    public init(selector: AudioObjectPropertySelector, status: OSStatus) {
        self.selector = selector
        self.status = status
    }

    /// 选择子的四字符码（如 `dev#`）：日志里能直接对回 HAL 属性，比裸数字好查。
    public var selectorCode: String {
        let characters = (0..<4).map { offset -> Character in
            let byte = UInt8(truncatingIfNeeded: selector >> (24 - 8 * UInt32(offset)))
            return (32...126).contains(byte) ? Character(UnicodeScalar(byte)) : "?"
        }
        return String(characters)
    }
}

/// 唯一测试接缝：隔离 Core Audio HAL。
///
/// 协议标注 `@MainActor`：调用方 `AudioDeviceManager` 与全部 UI 均在主线程，
/// 而 Swift 6 下 `@MainActor` 类型无法满足 nonisolated 协议需求（#ConformanceIsolation）。
/// 读取方法的失败通道见 `HALReadFailure`：SPEC 0006 原文的 `-> [AudioDevice]` 表达不了
/// 「读失败」，会把失败伪装成空列表，故按 0006 的修订版改成 typed throws。
@MainActor
public protocol AudioDeviceProviding {
    /// 含输入流的设备，按 HAL 返回顺序，名称为系统原文。
    /// 空数组 = HAL 答「没有输入设备」；HAL 报错则抛 `HALReadFailure`。
    func inputDevices() throws(HALReadFailure) -> [AudioDevice]

    /// 当前默认输入设备；`nil` = HAL 答「没有默认输入」，同样不是读取失败。
    func defaultInputDeviceID() throws(HALReadFailure) -> AudioDeviceID?

    func setDefaultInputDevice(id: AudioDeviceID) -> OSStatus
    func addListener(_ handler: @escaping () -> Void) -> Bool
    func removeListener()
}
