import SwiftUI
import AppKit
import VoiceInputCore

/// `swift run` 没有 Info.plist 的 LSUIElement，须在代码里声明 Accessory 进程模型，
/// 否则会占 Dock 图标。打包后的 .app 由 Info.plist 静态声明，此处是双保险。
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 单例锁。必须是强引用属性：对象一被释放，锁就随之归还，第二个实例又能起来。
    /// 进程活着它就一直持锁；进程退出（含崩溃、被 kill）时由内核回收。
    private let instanceGuard: SingleInstanceGuard

    override init() {
        // 在最早期判定单例：此时菜单栏图标还没创建，第二个进程可以干干净净地退掉，
        // 不会在菜单栏闪一下（`@NSApplicationDelegateAdaptor` 在 App init 阶段就实例化本类）。
        instanceGuard = SingleInstanceGuard(lockFileURL: SingleInstanceGuard.defaultLockFileURL)
        super.init()
        if instanceGuard.anotherInstanceIsRunning {
            // 用 exit 而非 NSApp.terminate(nil)：启动流程尚未开始，terminate 的
            // 「询问代理 → 停 run loop」链路在这个时点不可靠；而第二个进程什么 UI 都
            // 没建，直接退没有清理负担。原因已由 guard 写进系统日志（控制台可查）。
            exit(EXIT_SUCCESS)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct VoiceInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState(
        provider: CoreAudioDeviceProvider(),
        launchAtLoginService: SMAppServiceLoginItem()
    )

    var body: some Scene {
        MenuBarExtra {
            AudioDeviceMenuView(manager: state.manager, launchAtLogin: state.launchAtLogin)
        } label: {
            Image(systemName: "mic")
                .help("输入音源")
        }
        .menuBarExtraStyle(.menu)
    }
}
