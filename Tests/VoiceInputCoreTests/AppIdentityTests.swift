import Foundation
import Testing
import VoiceInputCore

/// 应用身份的「防漂移」检查。
///
/// `AppIdentity.fallbackBundleIdentifier` 必须与打包脚本写进 Info.plist 的 `BUNDLE_ID` 一致：
/// `swift run` 与已安装的 .app 共用同一把单例锁（见 `SingleInstanceGuard`），
/// 两个 id 一分叉，单例保护就悄悄失效。注释拦不住改名，这里直接读脚本来钉住。
@Suite("应用身份与打包脚本一致")
struct AppIdentityTests {
    /// 仓库根目录：本文件位于 `Tests/VoiceInputCoreTests/`，向上三层。
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests/VoiceInputCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // 仓库根
    }

    private func script(_ name: String) throws -> String {
        let url = Self.repositoryRoot
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent(name)
        return String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    @Test("bundle id 非空：日志 subsystem 与单例锁目录都靠它")
    func bundleIdentifierIsNotEmpty() {
        #expect(!AppIdentity.bundleIdentifier.isEmpty)
        #expect(!AppIdentity.fallbackBundleIdentifier.isEmpty)
    }

    @Test("回落的 bundle id 与打包脚本写进 Info.plist 的 BUNDLE_ID 一致")
    func fallbackMatchesPackagingScript() throws {
        let bundleApp = try script("bundle-app.sh")

        #expect(bundleApp.contains("BUNDLE_ID=\"\(AppIdentity.fallbackBundleIdentifier)\""))
    }

    @Test("安装脚本不再自带一份 bundle id，改为读安装包的 Info.plist")
    func installScriptHasNoSecondCopy() throws {
        let install = try script("install.sh")

        #expect(!install.contains(AppIdentity.fallbackBundleIdentifier))
        #expect(install.contains("CFBundleIdentifier"))
    }
}
