import Foundation
import Observation
import ServiceManagement

/// 登录项服务的最小抽象：真实现走 SMAppService，测试用替身。
@MainActor
public protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

/// `SMAppService.mainApp` 的真实现适配。
@MainActor
public struct SMAppServiceLoginItem: LoginItemService {
    private let service: SMAppService

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public var status: SMAppService.Status {
        service.status
    }

    public func register() throws {
        try service.register()
    }

    public func unregister() throws {
        try service.unregister()
    }

    public func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// 登录时启动开关的状态机：状态实时读 SMAppService，异常静默回显。
@Observable
@MainActor
public final class LaunchAtLoginController {
    private let service: any LoginItemService

    /// 登录项真实状态。存成属性而非每次现读，是为了让菜单能观察到变化并重新渲染。
    public private(set) var status: SMAppService.Status

    public init(service: any LoginItemService = SMAppServiceLoginItem()) {
        self.service = service
        self.status = service.status
    }

    public var presentation: LoginItemPresentation {
        LoginItemModel.presentation(for: status)
    }

    /// 重新读系统真实状态：用户随时可能在系统设置里关掉自启，不能缓存。
    public func refresh() {
        let latest = service.status
        if latest != status {
            status = latest
        }
    }

    /// 点击「登录时启动」：按真实状态决定注册 / 注销 / 引导系统设置。
    public func toggle() {
        refresh()
        switch LoginItemModel.action(for: status) {
        case .register:
            try? service.register()
        case .unregister:
            try? service.unregister()
        case .openSystemSettings:
            service.openSystemSettingsLoginItems()
        }
        refresh()
    }

    /// 引导用户在系统设置的登录项页放行（`.requiresApproval` 时的出路）。
    public func openSystemSettings() {
        service.openSystemSettingsLoginItems()
    }
}
