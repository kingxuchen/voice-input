import AppKit

/// 菜单相关的应用状态：设备列表 + 登录项开关，并保证「每次点开菜单都读系统真实状态」。
///
/// - 「菜单打开了」这个 UI 事件只在这里被翻译成「重读系统真实状态」的调用；
///   状态持有者（`AudioDeviceManager` / `LaunchAtLoginController`）只管自己那份状态的正确性。
/// - 触发点用 AppKit 的 `NSMenu.didBeginTrackingNotification`：SwiftUI `MenuBarExtra`
///   没有公开的 open 回调，`onAppear` 只在菜单视图首次出现时触发一次
///   （真机 AX 实证：连续开关菜单，只有第一次触发），代表不了「每次点开菜单」。
///   该通知在菜单开始跟踪时同步送达，且此时 SwiftUI 菜单的条目数组仍为空，
///   因此本次打开即可展示最新状态。
@MainActor
public final class AppState {
    public let manager: AudioDeviceManager
    public let launchAtLogin: LaunchAtLoginController

    private let menuOpenObserver: MenuOpenObserver

    /// - Parameters:
    ///   - provider: 音频设备接缝。
    ///   - launchAtLoginService: 登录项接缝。
    ///   - center: 通知中心；测试可注入独立实例。
    ///   - mainMenuProvider: 提供 App 主菜单，用于排除主菜单树的跟踪事件。
    public init(
        provider: any AudioDeviceProviding,
        launchAtLoginService: any LoginItemService,
        center: NotificationCenter = .default,
        mainMenuProvider: @escaping @MainActor () -> NSMenu? = { NSApp?.mainMenu }
    ) {
        let manager = AudioDeviceManager(provider: provider)
        let launchAtLogin = LaunchAtLoginController(service: launchAtLoginService)
        self.manager = manager
        self.launchAtLogin = launchAtLogin
        menuOpenObserver = MenuOpenObserver(
            center: center,
            mainMenuProvider: mainMenuProvider
        ) {
            manager.refresh()
            launchAtLogin.refresh()
        }
    }
}
