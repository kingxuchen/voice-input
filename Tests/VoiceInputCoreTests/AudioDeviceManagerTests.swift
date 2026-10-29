import Testing
import CoreAudio
@testable import VoiceInputCore

@Suite("AudioDeviceManager 设备列表与切换")
@MainActor
struct AudioDeviceManagerTests {
    private func makeProvider() -> FakeAudioDeviceProvider { makeStandardProvider() }

    private func standardState(defaultID: AudioDeviceID?) -> DeviceListState {
        .devices(
            [
                AudioDevice(id: 177, name: "vRemoteDr 2ch"),
                AudioDevice(id: 93, name: "MacBook Pro麦克风"),
                AudioDevice(id: 115, name: "BlackHole 2ch"),
            ],
            defaultID: defaultID
        )
    }

    @Test("初始化时装载设备列表与当前默认输入设备")
    func loadsDevicesOnInit() {
        let manager = AudioDeviceManager(provider: makeProvider())

        #expect(manager.state == standardState(defaultID: 177))
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
        #expect(manager.state == standardState(defaultID: 93))
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
        #expect(manager.state == standardState(defaultID: 177))
        #expect(manager.menuItems.first?.isDefault == true)
    }

    @Test("刷新后重新拉取设备列表与默认设备")
    func refreshReloadsState() {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider)

        provider.devices = [AudioDevice(id: 115, name: "BlackHole 2ch")]
        provider.defaultID = 115
        manager.refresh()

        #expect(manager.state == .devices([AudioDevice(id: 115, name: "BlackHole 2ch")], defaultID: 115))
        #expect(manager.menuItems.map(\.title) == ["✓  BlackHole 2ch"])
    }

    @Test("设备枚举失败时状态是 unreadable，而不是空列表")
    func deviceReadFailureIsUnreadable() {
        let provider = makeProvider()
        provider.devicesFailure = sampleReadFailure
        let manager = AudioDeviceManager(provider: provider)

        #expect(manager.state == .unreadable(sampleReadFailure))
        // 界面据此不列条目；「读不到」由 state 表达，不会被当成「一台都没有」。
        #expect(manager.menuItems.isEmpty)
    }

    @Test("默认输入读取失败也整份作废，不留下「有列表、无勾选」的半成品")
    func defaultReadFailureIsUnreadable() {
        let provider = makeProvider()
        provider.defaultFailure = sampleReadFailure
        let manager = AudioDeviceManager(provider: provider)

        #expect(manager.state == .unreadable(sampleReadFailure))
    }

    @Test("HAL 恢复正常后刷新能把状态从 unreadable 拉回正常快照")
    func refreshRecoversFromUnreadable() {
        let provider = makeProvider()
        provider.devicesFailure = sampleReadFailure
        let manager = AudioDeviceManager(provider: provider)
        #expect(manager.state == .unreadable(sampleReadFailure))

        provider.devicesFailure = nil
        manager.refresh()

        #expect(manager.state == standardState(defaultID: 177))
    }

    @Test("切换后的回读失败同样整份作废，不展示写之前的旧列表")
    func selectThenReadFailureIsUnreadable() {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider)

        // 写入确实生效，但回读读不到：界面必须整份作废，不能留着写之前的列表和勾选。
        provider.readFailureAfterWrite = sampleReadFailure
        manager.select(deviceID: 93)

        #expect(provider.setDefaultCalls == [93])
        #expect(manager.state == .unreadable(sampleReadFailure))
    }

    @Test("一台输入设备都没有是正常快照：devices 为空但状态不是 unreadable")
    func emptyDeviceListIsNotAFailure() {
        let provider = FakeAudioDeviceProvider()
        provider.devices = []
        provider.defaultID = nil
        let manager = AudioDeviceManager(provider: provider)

        #expect(manager.state == .devices([], defaultID: nil))
        #expect(manager.menuItems.isEmpty)
    }
}
