import CoreAudio

/// Core Audio HAL 真实现：枚举含输入流的设备、读写系统默认输入设备、监听属性变更。
///
/// 桥接范式（research/coreaudio-api-verification.md 第 6 节）：
/// 顶层 `nonisolated` C 函数指针作 `AudioObjectPropertyListenerProc`（Block 变体注销不可靠）、
/// `Unmanaged.passUnretained(self).toOpaque()` 传上下文、回调内 `Task { @MainActor in … }` 跳板、
/// `isolated deinit`（SE-0371）注销监听。CFString 一律 `takeRetainedValue()`。
///
/// 本实现只设默认输入、绝不创建音频流 —— 蓝牙耳机不会因此被拖进 HFP 降级。
@MainActor
public final class CoreAudioDeviceProvider: AudioDeviceProviding {
    private var handler: (() -> Void)?
    private var isListening = false

    private var devicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    public init() {}

    public func inputDevices() throws(HALReadFailure) -> [AudioDevice] {
        var size: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &devicesAddress, 0, nil, &size
        )
        guard sizeStatus == noErr else {
            throw HALReadFailure(selector: devicesAddress.mSelector, status: sizeStatus)
        }
        // size == 0 且 noErr 是 HAL 的正常回答：这台机器没有设备，返回空列表而不是报错。
        guard size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        let getStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &devicesAddress, 0, nil, &size, &deviceIDs
        )
        guard getStatus == noErr else {
            throw HALReadFailure(selector: devicesAddress.mSelector, status: getStatus)
        }

        return deviceIDs.compactMap { deviceID in
            // 单台设备的流属性读失败按「没有输入流」跳过：不能让一台读不到的设备
            // 把整张列表变成读取失败——那是逐设备的降级，不是整体失败。
            guard hasInputStreams(deviceID) else { return nil }
            // 读名失败也保留设备：菜单要列全所有输入设备，不能让它静默消失。
            let name = readString(deviceID, selector: kAudioDevicePropertyDeviceNameCFString) ?? "未知设备"
            return AudioDevice(id: deviceID, name: name)
        }
    }

    public func defaultInputDeviceID() throws(HALReadFailure) -> AudioDeviceID? {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, 0, nil, &size, &deviceID
        )
        guard status == noErr else {
            throw HALReadFailure(selector: defaultInputAddress.mSelector, status: status)
        }
        // HAL 答「没有默认输入」时回 kAudioObjectUnknown：这是一个答案，不是失败。
        return deviceID == kAudioObjectUnknown ? nil : deviceID
    }

    public func setDefaultInputDevice(id: AudioDeviceID) -> OSStatus {
        var deviceID = id
        var address = defaultInputAddress
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        return AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &deviceID
        )
    }

    public func addListener(_ handler: @escaping () -> Void) -> Bool {
        guard !isListening else { return false }

        let clientData = Unmanaged.passUnretained(self).toOpaque()
        let devicesStatus = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject), &devicesAddress, coreAudioListenerProc, clientData
        )
        guard devicesStatus == noErr else { return false }

        let defaultStatus = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, coreAudioListenerProc, clientData
        )
        guard defaultStatus == noErr else {
            // 第二个注册失败时必须撤掉第一个：否则它仍持有 self 指针，
            // 而 isListening 保持 false 会让 removeListener 永远跳过注销 → 释放后回调野指针。
            _ = AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject), &devicesAddress, coreAudioListenerProc, clientData
            )
            return false
        }

        isListening = true
        self.handler = handler
        return true
    }

    public func removeListener() {
        guard isListening else { return }
        let clientData = Unmanaged.passUnretained(self).toOpaque()
        _ = AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject), &devicesAddress, coreAudioListenerProc, clientData
        )
        _ = AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, coreAudioListenerProc, clientData
        )
        isListening = false
        handler = nil
    }

    fileprivate func notifyChanged() {
        handler?()
    }

    isolated deinit {
        removeListener()
    }

    private func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        return status == noErr && size > 0
    }

    private func readString(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var unmanagedString: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &unmanagedString)
        guard status == noErr, let unmanaged = unmanagedString else { return nil }
        return unmanaged.takeRetainedValue() as String
    }
}

/// 顶层 C 函数指针：全局代码段静态地址，注销时百分百对得上（Block 变体不可靠）。
private func coreAudioListenerProc(
    _ objectID: AudioObjectID,
    _ numberAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData else { return noErr }
    let provider = Unmanaged<CoreAudioDeviceProvider>.fromOpaque(clientData).takeUnretainedValue()
    Task { @MainActor in provider.notifyChanged() }
    return noErr
}
