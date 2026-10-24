import CoreAudio
import Foundation

/// `voiceinput-cli` 的对外契约（.issues/0017-cli-contract.md）。
///
/// 放在 `VoiceInputCore` 而不是进程入口里，是为了让 JSON 形状与退出码能被单测直接驱动；
/// 进程入口只负责写 stdout/stderr 并退出。
///
/// 设计约束：一次调用 = 一个进程 = 一次 HAL 现读，因此这里**不做任何缓存**。

// MARK: - 命令

enum CLIInvocation: Equatable, Sendable {
    case list(pretty: Bool)
    case setDefault(id: AudioDeviceID, pretty: Bool)
    case version(pretty: Bool)
    /// 参数形状不合法：退出码 2，错误码 `bad_usage`。
    case usageError(message: String, pretty: Bool)
}

enum CLIParser {
    static let usage = "usage: voiceinput-cli list|set-default <id>|version [--pretty]"

    /// 子命令风格：`list` / `set-default <id>` / `version`；`--pretty` 可出现在任意位置。
    static func parse(_ arguments: [String]) -> CLIInvocation {
        var rest = arguments
        let pretty = rest.contains("--pretty")
        rest.removeAll { $0 == "--pretty" }

        guard let subcommand = rest.first else { return .usageError(message: usage, pretty: pretty) }
        rest.removeFirst()

        switch subcommand {
        case "list", "version":
            guard rest.isEmpty else { return .usageError(message: usage, pretty: pretty) }
            return subcommand == "list" ? .list(pretty: pretty) : .version(pretty: pretty)
        case "set-default":
            guard rest.count == 1, let id = AudioDeviceID(rest[0]) else {
                return .usageError(message: usage, pretty: pretty)
            }
            return .setDefault(id: id, pretty: pretty)
        default:
            return .usageError(message: usage, pretty: pretty)
        }
    }
}

// MARK: - 执行结果

struct CLIExecution: Equatable, Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

/// 输出契约里的一款设备。`name` 是系统原文，`displayName` 是加了同名序号的用户可见名。
struct CLIDevice: Encodable, Equatable, Sendable {
    let id: AudioDeviceID
    let name: String
    let displayName: String
    let isDefault: Bool
}

let cliProtocolVersion = 1

// MARK: - 执行器

@MainActor
struct CLIRunner {
    private let provider: any AudioDeviceProviding
    private let appVersion: String

    init(provider: any AudioDeviceProviding, appVersion: String) {
        self.provider = provider
        self.appVersion = appVersion
    }

    func run(_ invocation: CLIInvocation) -> CLIExecution {
        switch invocation {
        case let .list(pretty):
            let devices = readDevices()
            return devices.map { success(DeviceListPayload(protocol: cliProtocolVersion, devices: $0), pretty: pretty) }
                ?? halError("cannot read audio devices", pretty: pretty)

        case let .version(pretty):
            return success(VersionPayload(protocol: cliProtocolVersion, appVersion: appVersion), pretty: pretty)

        case let .usageError(message, pretty):
            return failure(code: .badUsage, message: message, exitCode: 2, pretty: pretty)

        case let .setDefault(id, pretty):
            return setDefault(id: id, pretty: pretty)
        }
    }

    private func setDefault(id: AudioDeviceID, pretty: Bool) -> CLIExecution {
        guard let devices = readDevices() else {
            return halError("cannot read audio devices", pretty: pretty)
        }
        guard devices.contains(where: { $0.id == id }) else {
            return failure(code: .deviceNotFound, message: "no input device with id \(id)", exitCode: 4, pretty: pretty)
        }

        let status = provider.setDefaultInputDevice(id: id)
        guard status == noErr else {
            return failure(
                code: .switchFailed,
                message: "cannot set default input device (OSStatus \(status))",
                exitCode: 4,
                pretty: pretty
            )
        }

        // 契约要求返回回读状态，而不是回显入参：系统可能拒绝、回落或另有变化。
        guard let refreshed = readDevices() else {
            return halError("cannot read audio devices after switching", pretty: pretty)
        }
        return success(DeviceListPayload(protocol: cliProtocolVersion, devices: refreshed), pretty: pretty)
    }

    /// 读设备列表并把「当前默认」落到 `isDefault` 上。
    ///
    /// 三种情况都算读取失败（返回 nil），因为任何一种都无法诚实地渲染列表：
    /// - 枚举返回空（HAL 失败与「真的没有输入设备」对调用方是同一件事：没有可切的目标）；
    /// - 读不到当前默认输入；
    /// - 当前默认输入的 id 不在枚举结果里（设备刚被拔掉）。
    private func readDevices() -> [CLIDevice]? {
        let raw = provider.inputDevices()
        guard !raw.isEmpty, let defaultID = provider.defaultInputDeviceID() else { return nil }
        guard raw.contains(where: { $0.id == defaultID }) else { return nil }

        let names = MenuModel.displayNames(for: raw)
        return raw.enumerated().map { index, device in
            CLIDevice(
                id: device.id,
                name: device.name,
                displayName: names[index],
                isDefault: device.id == defaultID
            )
        }
    }
}

// MARK: - 编码

private enum CLIErrorCode: String {
    case badUsage = "bad_usage"
    case halError = "hal_error"
    case deviceNotFound = "device_not_found"
    case switchFailed = "switch_failed"
}

private struct DeviceListPayload: Encodable {
    let `protocol`: Int
    let devices: [CLIDevice]
}

private struct VersionPayload: Encodable {
    let `protocol`: Int
    let appVersion: String
}

private struct ErrorPayload: Encodable {
    struct Detail: Encodable {
        let code: String
        let message: String
    }

    let `protocol`: Int
    let error: Detail
}

private extension CLIRunner {
    /// 编码失败在现实里不可达（载荷只有 String/Int/Bool/数组），但吞掉它会输出空行 + 退出码 0，
    /// 那等于骗调用方「成功」；这里退化为一条固定的错误 JSON，仍遵守「JSON 恒输出」。
    static let encodingFailureJSON =
        #"{"error":{"code":"hal_error","message":"cannot encode response"},"protocol":\#(cliProtocolVersion)}"# + "\n"

    func success(_ payload: some Encodable, pretty: Bool) -> CLIExecution {
        guard let text = encode(payload, pretty: pretty) else {
            return CLIExecution(stdout: Self.encodingFailureJSON, stderr: "cannot encode response\n", exitCode: 3)
        }
        return CLIExecution(stdout: text + "\n", stderr: "", exitCode: 0)
    }

    func halError(_ message: String, pretty: Bool) -> CLIExecution {
        failure(code: .halError, message: message, exitCode: 3, pretty: pretty)
    }

    func failure(code: CLIErrorCode, message: String, exitCode: Int32, pretty: Bool) -> CLIExecution {
        let payload = ErrorPayload(
            protocol: cliProtocolVersion,
            error: .init(code: code.rawValue, message: message)
        )
        guard let text = encode(payload, pretty: pretty) else {
            return CLIExecution(stdout: Self.encodingFailureJSON, stderr: "cannot encode response\n", exitCode: 3)
        }
        return CLIExecution(stdout: text + "\n", stderr: message + "\n", exitCode: exitCode)
    }

    func encode(_ object: some Encodable, pretty: Bool) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        guard let data = try? encoder.encode(object) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - 进程入口

/// 唯一的对外符号：`voiceinput-cli` 可执行目标只调它，解析/执行/编码都留在本 module 内可见（可测）。
public enum CLIEntry {
    /// 打印结果并退出进程。`appVersion` 由调用方从 Info.plist 读（bundle 版本是唯一来源）。
    @MainActor
    public static func run(arguments: [String], appVersion: String) -> Never {
        let execution = CLIRunner(provider: CoreAudioDeviceProvider(), appVersion: appVersion)
            .run(CLIParser.parse(arguments))

        FileHandle.standardOutput.write(Data(execution.stdout.utf8))
        if !execution.stderr.isEmpty {
            FileHandle.standardError.write(Data(execution.stderr.utf8))
        }
        exit(execution.exitCode)
    }
}
