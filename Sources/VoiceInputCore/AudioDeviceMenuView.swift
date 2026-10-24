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
        if manager.devices.isEmpty {
            Text("未发现可用输入设备")
                .foregroundStyle(.secondary)
        } else {
            ForEach(manager.menuItems) { item in
                Button(item.title) {
                    manager.select(deviceID: item.id)
                }
            }
        }

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
}
