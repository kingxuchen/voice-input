import ServiceManagement

public struct LoginItemPresentation: Equatable, Sendable {
    public let title: String
    public let showsApprovalHint: Bool
    public let hintTitle: String

    public init(title: String, showsApprovalHint: Bool, hintTitle: String) {
        self.title = title
        self.showsApprovalHint = showsApprovalHint
        self.hintTitle = hintTitle
    }
}

public enum LoginItemAction: Equatable, Sendable {
    case register
    case unregister
    case openSystemSettings
}

public enum LoginItemModel {
    public static let menuTitle = "登录时启动"
    public static let hintTitle = "需在系统设置中允许自启…"

    public static func presentation(for status: SMAppService.Status) -> LoginItemPresentation {
        switch status {
        case .enabled:
            return LoginItemPresentation(
                title: MenuModel.defaultPrefix + menuTitle,
                showsApprovalHint: false,
                hintTitle: hintTitle
            )
        case .requiresApproval:
            // 系统里被用户关了开关：此时 register 无效，只能引导去系统设置放行。
            return LoginItemPresentation(
                title: MenuModel.plainPrefix + menuTitle,
                showsApprovalHint: true,
                hintTitle: hintTitle
            )
        case .notRegistered, .notFound:
            return plainPresentation
        @unknown default:
            return plainPresentation
        }
    }

    public static func action(for status: SMAppService.Status) -> LoginItemAction {
        switch status {
        case .enabled:
            return .unregister
        case .requiresApproval:
            return .openSystemSettings
        case .notRegistered, .notFound:
            return .register
        @unknown default:
            return .register
        }
    }

    private static var plainPresentation: LoginItemPresentation {
        LoginItemPresentation(title: MenuModel.plainPrefix + menuTitle, showsApprovalHint: false, hintTitle: hintTitle)
    }
}
