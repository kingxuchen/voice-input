import AppKit

/// 状态栏菜单「即将显示」的信号源。
///
/// SwiftUI `MenuBarExtra` 没有公开的 open 回调；`onAppear` 只在菜单视图首次出现时触发一次
/// （真机 AX 实证：连续开关菜单，只有第一次触发），代表不了「每次点开菜单」。
///
/// AppKit 的 `NSMenu.didBeginTrackingNotification` 在菜单每次开始跟踪时发出，且同步送达；
/// 真机实证该通知到达时 SwiftUI 菜单的条目数组仍为空，因此在此触发刷新，
/// 本次打开即可看到最新状态。
@MainActor
public final class MenuOpenObserver {
    private let center: NotificationCenter
    private let mainMenuProvider: @MainActor () -> NSMenu?
    private let onOpen: @MainActor () -> Void
    private var token: NSObjectProtocol?

    /// - Parameters:
    ///   - center: 通知中心；测试可注入独立实例，避免互相干扰。
    ///   - mainMenuProvider: 提供 App 主菜单，用于排除主菜单树的跟踪事件。
    ///   - onOpen: 状态栏菜单即将显示时调用（主 actor）。
    public init(
        center: NotificationCenter = .default,
        mainMenuProvider: @escaping @MainActor () -> NSMenu? = { NSApp?.mainMenu },
        onOpen: @escaping @MainActor () -> Void
    ) {
        self.center = center
        self.mainMenuProvider = mainMenuProvider
        self.onOpen = onOpen
        token = center.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self, let menu = notification.object as? NSMenu else { return }
            // NSMenu 不可跨并发域传递，只把身份（Sendable）带进主 actor。
            let identity = ObjectIdentifier(menu)
            // 通知由 AppKit 在主线程发出；跨线程兜底走 Task，避免丢事件。
            if Thread.isMainThread {
                MainActor.assumeIsolated { self.handle(identity) }
            } else {
                Task { @MainActor in self.handle(identity) }
            }
        }
    }

    isolated deinit {
        if let token {
            center.removeObserver(token)
        }
    }

    private func handle(_ identity: ObjectIdentifier) {
        guard !MenuOpenObserver.isInMainMenuTree(identity, mainMenu: mainMenuProvider()) else { return }
        onOpen()
    }

    /// 菜单是否属于 App 主菜单树（Apple 菜单 / App 菜单及其各级子菜单）——那些不是状态栏菜单。
    ///
    /// 状态栏菜单是独立菜单，不在主菜单树内（真机 AX 实证：其 `supermenu` 为 nil）。
    static func isInMainMenuTree(_ identity: ObjectIdentifier, mainMenu: NSMenu?) -> Bool {
        guard let mainMenu else { return false }
        var stack: [NSMenu] = [mainMenu]
        while let menu = stack.popLast() {
            if ObjectIdentifier(menu) == identity { return true }
            stack.append(contentsOf: menu.items.compactMap(\.submenu))
        }
        return false
    }
}
