import SwiftUI
import AppKit
import VoiceInputCore

/// `swift run` 没有 Info.plist 的 LSUIElement，须在代码里声明 Accessory 进程模型，
/// 否则会占 Dock 图标。打包后的 .app 由 Info.plist 静态声明，此处是双保险。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct VoiceInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var manager = AudioDeviceManager(provider: CoreAudioDeviceProvider())
    @State private var launchAtLogin = LaunchAtLoginController()

    var body: some Scene {
        MenuBarExtra {
            AudioDeviceMenuView(manager: manager, launchAtLogin: launchAtLogin)
        } label: {
            Image(systemName: "mic")
                .help("输入音源")
        }
        .menuBarExtraStyle(.menu)
    }
}
