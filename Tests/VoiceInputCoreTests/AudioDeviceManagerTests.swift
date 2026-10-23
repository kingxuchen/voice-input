import Testing
import CoreAudio
@testable import VoiceInputCore

@Suite("AudioDeviceManager 设备列表与切换")
@MainActor
struct AudioDeviceManagerTests {
    private func makeProvider() -> FakeAudioDeviceProvider { makeStandardProvider() }

    @Test("初始化时装载设备列表与当前默认输入设备")
    func loadsDevicesOnInit() {
        let provider = makeProvider()

        let manager = AudioDeviceManager(provider: provider)

        #expect(manager.devices.map(\.name) == ["vRemoteDr 2ch", "MacBook Pro麦克风", "BlackHole 2ch"])
        #expect(manager.defaultDeviceID == 177)
    }

    @Test("菜单项保持 HAL 顺序，默认设备带勾选前缀")
    func buildsMenuItemsInHalOrder() {
        let manager = AudioDeviceManager(provider: makeProvider())

        #expect(manager.menuItems.map(\.title) == [
            "✓  vRemoteDr 2ch",
            "    MacBook Pro麦克风",
            "    BlackHole 2ch",
        ])
    }

    @Test("选择设备即调用 provider 设为默认输入，并更新勾选位置")
    func selectSetsDefaultDevice() {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider)

        manager.select(deviceID: 93)

        #expect(provider.setDefaultCalls == [93])
        #expect(manager.defaultDeviceID == 93)
        #expect(manager.menuItems.map(\.title) == [
            "    vRemoteDr 2ch",
            "✓  MacBook Pro麦克风",
            "    BlackHole 2ch",
        ])
    }

    @Test("切换失败静默：默认设备与勾选保持原状")
    func failedSelectKeepsDefault() {
        let provider = makeProvider()
        provider.setDefaultStatus = 1
        let manager = AudioDeviceManager(provider: provider)

        manager.select(deviceID: 93)

        #expect(provider.setDefaultCalls == [93])
        #expect(manager.defaultDeviceID == 177)
        #expect(manager.menuItems.first?.isDefault == true)
    }

    @Test("刷新后重新拉取设备列表与默认设备")
    func refreshReloadsState() {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider)

        provider.devices = [AudioDevice(id: 115, name: "BlackHole 2ch")]
        provider.defaultID = 115
        manager.refresh()

        #expect(manager.devices.map(\.name) == ["BlackHole 2ch"])
        #expect(manager.defaultDeviceID == 115)
        #expect(manager.menuItems.map(\.title) == ["✓  BlackHole 2ch"])
    }
}
