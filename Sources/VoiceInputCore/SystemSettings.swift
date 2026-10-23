import Foundation

public enum SystemSettings {
    /// 「声音」设置页。bundle id 取自 `/System/Library/ExtensionKit/Extensions/Sound.appex`
    /// 的真实 CFBundleIdentifier；拼错会静默不跳转（SPEC 0006 的笔误已修正）。
    public static let soundSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Sound-Settings.extension"
    )!
}
