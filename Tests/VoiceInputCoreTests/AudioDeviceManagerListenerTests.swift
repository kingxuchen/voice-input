import Testing
import CoreAudio
@testable import VoiceInputCore

@Suite("AudioDeviceManager 属性监听与防抖刷新")
@MainActor
struct AudioDeviceManagerListenerTests {
    private func makeProvider() -> FakeAudioDeviceProvider { makeStandardProvider() }

    @Test("监听事件触发后刷新设备列表")
    func listenerRefreshesDeviceList() async throws {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider)

        provider.devices = [AudioDevice(id: 115, name: "BlackHole 2ch")]
        provider.fireChanged()

        #expect(await eventually { manager.devices.map(\.name) == ["BlackHole 2ch"] })
    }

    @Test("防抖窗口内不刷新，窗口过后才刷新")
    func refreshIsDebounced() async throws {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider, debounceInterval: .milliseconds(300))
        let readsAfterInit = provider.deviceReadCount

        provider.fireChanged()
        try await Task.sleep(for: .milliseconds(100))
        #expect(provider.deviceReadCount == readsAfterInit)

        try await Task.sleep(for: .milliseconds(800))
        #expect(provider.deviceReadCount == readsAfterInit + 1)
        _ = manager
    }

    @Test("连续多个事件只触发一次刷新")
    func burstEventsCollapseIntoSingleRefresh() async throws {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider, debounceInterval: .milliseconds(100))
        let readsAfterInit = provider.deviceReadCount

        provider.fireChanged()
        provider.fireChanged()
        provider.fireChanged()

        try await Task.sleep(for: .milliseconds(800))

        #expect(provider.deviceReadCount == readsAfterInit + 1)
        _ = manager
    }

    @Test("系统别处改了默认输入后，勾选自动跟随")
    func defaultChangeFollowsSystemDefault() async throws {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider)

        provider.defaultID = 93
        provider.fireChanged()

        #expect(await eventually { manager.defaultDeviceID == 93 })
        #expect(manager.menuItems.map(\.title) == [
            "    vRemoteDr 2ch",
            "✓  MacBook Pro麦克风",
            "    BlackHole 2ch",
        ])
    }

    @Test("拔出当前默认设备后，勾选跳到系统回落设备")
    func unpluggedDefaultFallsBackToSystemChoice() async throws {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider)

        provider.devices = [
            AudioDevice(id: 93, name: "MacBook Pro麦克风"),
            AudioDevice(id: 115, name: "BlackHole 2ch"),
        ]
        provider.defaultID = 93
        provider.fireChanged()

        #expect(await eventually { manager.defaultDeviceID == 93 })
        #expect(manager.menuItems.map(\.title) == [
            "✓  MacBook Pro麦克风",
            "    BlackHole 2ch",
        ])
    }

    @Test("切换失败静默：勾选对齐系统真实默认")
    func failedSelectAlignsWithRealDefault() async throws {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider)

        provider.setDefaultStatus = 1
        provider.defaultID = 115
        manager.select(deviceID: 93)

        #expect(provider.setDefaultCalls == [93])
        #expect(manager.defaultDeviceID == 115)
        #expect(manager.menuItems.first(where: { $0.id == 115 })?.isDefault == true)
        #expect(manager.menuItems.first(where: { $0.id == 177 })?.isDefault == false)
    }

    @Test("防抖窗口内的切换不被过期刷新覆盖")
    func pendingRefreshDoesNotOverrideFreshSelection() async throws {
        let provider = makeProvider()
        let manager = AudioDeviceManager(provider: provider, debounceInterval: .milliseconds(150))

        provider.fireChanged()
        manager.select(deviceID: 93)

        try await Task.sleep(for: .milliseconds(700))

        #expect(manager.defaultDeviceID == 93)
        #expect(manager.menuItems.first(where: { $0.id == 93 })?.isDefault == true)
    }
}
