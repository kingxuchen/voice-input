import SwiftUI
import AppKit

/// 菜单内容独立成子视图：`MenuBarExtra` 闭包内联的 `ForEach` 会让 `@Observable` 依赖订阅失效
/// （research/coreaudio-api-verification.md 第 5 节）。
public struct AudioDeviceMenuView: View {
    private let manager: AudioDeviceManager
    private let launchAtLogin: LaunchAtLoginController

    public init(manager: AudioDeviceManager, launchAtLogin: LaunchAtLoginController) {
        self.manager = manager
        self.launchAtLogin = launchAtLogin
    }

    public var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        deviceSection

        Divider()

        Button("打开声音设置…") {
            NSWorkspace.shared.open(SystemSettings.soundSettingsURL)
        }

        Button(launchAtLogin.presentation.title) {
            launchAtLogin.toggle()
        }

        if launchAtLogin.presentation.showsApprovalHint {
            Button(launchAtLogin.presentation.hintTitle) {
                launchAtLogin.openSystemSettings()
            }
        }

        Divider()

        Button("退出 VoiceInput") {
            NSApplication.shared.terminate(nil)
        }
    }

    /// 三个事实分开说：有设备就列；读到了但一台都没有，说「未发现」；
    /// 读不到就说「无法读取」——不能再用「没有设备」给 HAL 的故障圆场。
    @ViewBuilder
    private var deviceSection: some View {
        switch manager.state {
        case let .devices(devices, _) where devices.isEmpty:
            Text("未发现可用输入设备")
                .foregroundStyle(.secondary)
        case .devices:
            ForEach(manager.menuItems) { item in
                Button(item.title) {
                    manager.select(deviceID: item.id)
                }
            }
        case let .unreadable(failure):
            // 菜单不是诊断通道：细节（HAL 属性四字符码 + OSStatus）只作提示，正文说清「读不到」即可。
            Text("无法读取音频设备")
                .foregroundStyle(.secondary)
                .help("\(failure.selectorCode) OSStatus \(failure.status)")
        }
    }
}
