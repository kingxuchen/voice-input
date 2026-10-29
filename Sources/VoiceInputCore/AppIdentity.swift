import Foundation
import OSLog

/// 应用身份的单一来源：bundle id 与由它派生的日志 subsystem。
///
/// 打包成 `.app` 之后，权威值只有一处——`scripts/bundle-app.sh` 写进 Info.plist 的
/// `CFBundleIdentifier`，代码直接问 `Bundle.main` 要，不再自己抄一遍字符串。
///
/// `swift run` / `swift test` 没有真实 app bundle，`Bundle.main.bundleIdentifier` 可能是 nil，
/// 那时才回落到常量。回落值必须与打包脚本的 `BUNDLE_ID` 一致：`swift run` 与已安装的 .app
/// 共用同一把单例锁（见 `SingleInstanceGuard`），两者 id 分叉就等于单例保护悄悄失效。
/// 这处人工同步由 `AppIdentityTests` 直接读打包脚本来钉住，改名却忘了同步会让测试先红。
public enum AppIdentity {
    /// 无 app bundle 时（`swift run` / `swift test`）使用的标识，须与 `scripts/bundle-app.sh` 一致。
    public static let fallbackBundleIdentifier = "com.fanbingbing.voiceinput"

    /// 当前进程所属应用的 bundle id。
    public static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier
    }

    /// 统一日志的出口。subsystem 恒等于应用身份，与锁文件放在哪无关。
    public static func logger(category: String) -> Logger {
        Logger(subsystem: bundleIdentifier, category: category)
    }
}
