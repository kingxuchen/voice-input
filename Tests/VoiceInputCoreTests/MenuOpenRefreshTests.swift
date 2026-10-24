import Testing
import AppKit
import CoreAudio
@testable import VoiceInputCore

/// 「每次点开菜单都重读系统真实状态」的接线验证。
///
/// 触发点是 AppKit 的 `NSMenu.didBeginTrackingNotification`：菜单每次开始跟踪时同步送达，
/// 早于 SwiftUI 用状态构建菜单条目，因此本次打开即可展示最新音源。
@Suite("菜单打开即重读系统真实状态")
@MainActor
struct MenuOpenRefreshTests {
    /// 用独立通知中心，避免与真实 App 的通知互相干扰。
    private func makeState(
        provider: FakeAudioDeviceProvider,
        service: FakeLoginItemService,
        center: NotificationCenter,
        mainMenuProvider: @escaping @MainActor () -> NSMenu? = { nil }
    ) -> AppState {
        AppState(
            provider: provider,
            launchAtLoginService: service,
            center: center,
            mainMenuProvider: mainMenuProvider
        )
    }

    @Test("菜单打开后重新拉取设备列表与默认输入设备")
    func menuOpenReloadsDeviceList() async {
        let provider = makeStandardProvider()
        let service = FakeLoginItemService()
        let center = NotificationCenter()
        let state = makeState(provider: provider, service: service, center: center)
        let readsAfterInit = provider.deviceReadCount

        provider.devices = [AudioDevice(id: 115, name: "BlackHole 2ch")]
        provider.defaultID = 115
        center.post(name: NSMenu.didBeginTrackingNotification, object: NSMenu())

        #expect(await eventually { state.manager.devices.map(\.name) == ["BlackHole 2ch"] })
        #expect(state.manager.defaultDeviceID == 115)
        #expect(provider.deviceReadCount > readsAfterInit)
    }

    @Test("菜单打开后重新读取系统真实登录项状态")
    func menuOpenReloadsLoginItemStatus() async {
        let provider = makeStandardProvider()
        let service = FakeLoginItemService()
        service.status = .notRegistered
        let center = NotificationCenter()
        let state = makeState(provider: provider, service: service, center: center)

        // 用户在系统设置里改掉了自启状态，App 缓存仍是旧的
        service.status = .enabled
        center.post(name: NSMenu.didBeginTrackingNotification, object: NSMenu())

        #expect(await eventually { state.launchAtLogin.status == .enabled })
        #expect(state.launchAtLogin.presentation.title == "✓  登录时启动")
    }

    @Test("主菜单树的菜单被排除：不会误触发刷新")
    func mainMenuTrackingDoesNotRefresh() async {
        let provider = makeStandardProvider()
        let service = FakeLoginItemService()
        let center = NotificationCenter()
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let item = NSMenuItem(title: "App", action: nil, keyEquivalent: "")
        item.submenu = appMenu
        mainMenu.addItem(item)
        _ = makeState(
            provider: provider,
            service: service,
            center: center,
            mainMenuProvider: { mainMenu }
        )
        let readsAfterInit = provider.deviceReadCount

        center.post(name: NSMenu.didBeginTrackingNotification, object: appMenu)

        #expect(await eventually { provider.deviceReadCount == readsAfterInit })
    }
}
