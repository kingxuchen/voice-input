import Testing
import CoreAudio
@testable import VoiceInputCore

@Suite("CoreAudioDeviceProvider 真实现")
@MainActor
struct CoreAudioDeviceProviderTests {
    @Test("枚举出的设备名称非空且 ID 唯一")
    func enumeratesInputDevices() throws {
        let provider = CoreAudioDeviceProvider()

        let devices = try provider.inputDevices()

        #expect(!devices.isEmpty)
        #expect(devices.allSatisfy { !$0.name.isEmpty })
        #expect(Set(devices.map(\.id)).count == devices.count)
    }

    @Test("默认输入设备 ID 落在枚举出的设备集合内")
    func defaultInputIsEnumeratedDevice() throws {
        let provider = CoreAudioDeviceProvider()

        let defaultID = try provider.defaultInputDeviceID()
        let devices = try provider.inputDevices()

        if let defaultID {
            #expect(devices.contains { $0.id == defaultID })
        }
    }

    @Test("监听器可注册、注销并重新注册")
    func listenerLifecycle() {
        let provider = CoreAudioDeviceProvider()

        let firstRegistration = provider.addListener {}
        provider.removeListener()
        let secondRegistration = provider.addListener {}
        provider.removeListener()

        #expect(firstRegistration)
        #expect(secondRegistration)
    }

    @Test("重复注册被拒绝，不会叠加监听器")
    func duplicateRegistrationIsRejected() {
        let provider = CoreAudioDeviceProvider()

        #expect(provider.addListener {})
        #expect(!provider.addListener {})
        provider.removeListener()
    }
}
