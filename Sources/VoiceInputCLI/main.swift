import Foundation
import VoiceInputCore

// `voiceinput-cli`：进程接线只有这一行 —— 版本取自 Info.plist（`scripts/bundle-app.sh` 的 VERSION
// 是唯一来源），其余逻辑都在 VoiceInputCore 里，可被单测直接驱动。
CLIEntry.run(
    arguments: Array(CommandLine.arguments.dropFirst()),
    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0-dev"
)
