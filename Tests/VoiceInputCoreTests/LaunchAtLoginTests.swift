import Testing
import ServiceManagement
@testable import VoiceInputCore

/// 可控的登录项服务替身：不触碰系统真实登录项。
@MainActor
final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0
    private(set) var openSettingsCalls = 0
    var registerError: (any Error)?

    func register() throws {
        registerCalls += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCalls += 1
        status = .notRegistered
    }

    func openSystemSettingsLoginItems() {
        openSettingsCalls += 1
    }
}

@Suite("LaunchAtLogin 状态映射")
struct LaunchAtLoginModelTests {
    @Test("已启用：标题带勾选前缀，不显示引导项")
    func enabledShowsCheckmark() {
        let presentation = LoginItemModel.presentation(for: .enabled)

        #expect(presentation.title.hasPrefix("✓  "))
        #expect(!presentation.showsApprovalHint)
        #expect(presentation.title == "✓  登录时启动")
    }

    @Test("未注册：标题无勾选，不显示引导项")
    func notRegisteredShowsNoCheckmark() {
        let presentation = LoginItemModel.presentation(for: .notRegistered)

        #expect(!presentation.title.hasPrefix("✓  "))
        #expect(!presentation.showsApprovalHint)
        #expect(presentation.title == "    登录时启动")
    }

    @Test("需用户授权：不勾选且显示引导项")
    func requiresApprovalShowsHint() {
        let presentation = LoginItemModel.presentation(for: .requiresApproval)

        #expect(!presentation.title.hasPrefix("✓  "))
        #expect(presentation.showsApprovalHint)
        #expect(presentation.title == "    登录时启动")
        #expect(presentation.hintTitle == "需在系统设置中允许自启…")
    }

    @Test("找不到服务：按未注册呈现")
    func notFoundTreatedAsNotRegistered() {
        let presentation = LoginItemModel.presentation(for: .notFound)

        #expect(!presentation.title.hasPrefix("✓  "))
        #expect(!presentation.showsApprovalHint)
        #expect(presentation.title == "    登录时启动")
    }

    @Test("状态 → 点击动作：已启用则注销")
    func enabledMapsToUnregister() {
        #expect(LoginItemModel.action(for: .enabled) == .unregister)
    }

    @Test("状态 → 点击动作：未注册则注册")
    func notRegisteredMapsToRegister() {
        #expect(LoginItemModel.action(for: .notRegistered) == .register)
    }

    @Test("状态 → 点击动作：需用户授权则引导系统设置（register 无效）")
    func requiresApprovalMapsToOpenSystemSettings() {
        #expect(LoginItemModel.action(for: .requiresApproval) == .openSystemSettings)
    }

    @Test("状态 → 点击动作：找不到服务按注册处理")
    func notFoundMapsToRegister() {
        #expect(LoginItemModel.action(for: .notFound) == .register)
    }

    @Test("勾选态与点击动作一致：勾选即注销，未勾选即注册")
    func checkmarkAgreesWithAction() {
        #expect(LoginItemModel.presentation(for: .enabled).title.hasPrefix("✓  ") != (LoginItemModel.action(for: .enabled) == .register))
        #expect(LoginItemModel.presentation(for: .notRegistered).title.hasPrefix("✓  ") != (LoginItemModel.action(for: .notRegistered) == .register))
    }
}

@Suite("LaunchAtLoginController 切换行为")
@MainActor
struct LaunchAtLoginControllerTests {
    @Test("未注册时点击即注册")
    func togglingFromNotRegisteredRegisters() {
        let service = FakeLoginItemService()
        service.status = .notRegistered
        let controller = LaunchAtLoginController(service: service)

        controller.toggle()

        #expect(service.registerCalls == 1)
        #expect(service.unregisterCalls == 0)
        #expect(service.openSettingsCalls == 0)
    }

    @Test("已启用时点击即注销")
    func togglingFromEnabledUnregisters() {
        let service = FakeLoginItemService()
        service.status = .enabled
        let controller = LaunchAtLoginController(service: service)

        controller.toggle()

        #expect(service.unregisterCalls == 1)
        #expect(service.registerCalls == 0)
        #expect(service.openSettingsCalls == 0)
    }

    @Test("需用户授权时点击引导打开登录项设置页，不注册也不注销")
    func togglingFromRequiresApprovalOpensSystemSettings() {
        let service = FakeLoginItemService()
        service.status = .requiresApproval
        let controller = LaunchAtLoginController(service: service)

        controller.toggle()

        #expect(service.openSettingsCalls == 1)
        #expect(service.registerCalls == 0)
        #expect(service.unregisterCalls == 0)
    }

    @Test("注册失败静默：状态回显保持未注册")
    func registerFailureIsSilent() {
        let service = FakeLoginItemService()
        service.status = .notRegistered
        service.registerError = NSError(domain: "test", code: 1)
        let controller = LaunchAtLoginController(service: service)

        controller.toggle()

        #expect(service.registerCalls == 1)
        #expect(controller.status == .notRegistered)
        #expect(!controller.presentation.title.hasPrefix("✓  "))
    }

    @Test("状态实时读服务：refresh 后反映外部改动")
    func statusIsReadLive() {
        let service = FakeLoginItemService()
        service.status = .notRegistered
        let controller = LaunchAtLoginController(service: service)

        #expect(controller.presentation.title.hasPrefix("✓  ") == false)

        service.status = .enabled
        controller.refresh()

        #expect(controller.presentation.title.hasPrefix("✓  ") == true)
        #expect(controller.presentation.title == "✓  登录时启动")
    }

    @Test("refresh 重新读系统状态：外部改动后刷新即生效")
    func refreshReadsSystemStatusAgain() {
        let service = FakeLoginItemService()
        service.status = .notRegistered
        let controller = LaunchAtLoginController(service: service)

        service.status = .enabled

        controller.refresh()

        #expect(controller.status == .enabled)
        #expect(controller.presentation.title.hasPrefix("✓  "))
        #expect(controller.presentation.title == "✓  登录时启动")
    }

    @Test("状态是可观察属性：变更时通知订阅者（菜单才能重新渲染）")
    func statusIsObservable() {
        let service = FakeLoginItemService()
        service.status = .notRegistered
        let controller = LaunchAtLoginController(service: service)

        nonisolated(unsafe) var notified = false
        withObservationTracking {
            _ = controller.status
        } onChange: {
            notified = true
        }

        service.status = .enabled
        controller.refresh()

        #expect(notified)
    }

    @Test("切换后立即回显新状态，无需重启 App")
    func toggleEchoesNewStatusImmediately() {
        let service = FakeLoginItemService()
        service.status = .notRegistered
        let controller = LaunchAtLoginController(service: service)

        controller.toggle()

        #expect(controller.status == .enabled)
        #expect(controller.presentation.title.hasPrefix("✓  "))
        #expect(controller.presentation.title == "✓  登录时启动")
    }

    @Test("缓存过期时点击先读系统真实状态：已被系统关成需授权则引导而非注册")
    func toggleReadsRealStatusBeforeActing() {
        let service = FakeLoginItemService()
        service.status = .notRegistered
        let controller = LaunchAtLoginController(service: service)

        // 用户在系统设置里把自启关掉了，App 里的缓存还停在未注册
        service.status = .requiresApproval

        controller.toggle()

        #expect(service.openSettingsCalls == 1)
        #expect(service.registerCalls == 0)
    }
}

@Suite("系统设置深链")
struct SystemSettingsURLTests {
    @Test("声音设置 URL 指向系统真实的声音设置扩展")
    func soundSettingsURLTargetsRealExtension() throws {
        let plistPath = "/System/Library/ExtensionKit/Extensions/Sound.appex/Contents/Info.plist"
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String
        else {
            return  // 本机没有该扩展时无法对照
        }

        #expect(SystemSettings.soundSettingsURL.scheme == "x-apple.systempreferences")
        #expect(SystemSettings.soundSettingsURL.path == bundleID)
    }
}
