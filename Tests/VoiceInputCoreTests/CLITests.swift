import Testing
import CoreAudio
import Foundation
@testable import VoiceInputCore

/// `voiceinput-cli` 的对外契约（.issues/0017-cli-contract.md）。
/// 只测外部可见行为：JSON 形状、退出码、错误码、回读语义；不测 Core Audio 内部。
@Suite("voiceinput-cli 命令解析")
struct CLIParserTests {
    @Test("list 解析为列举设备")
    func parsesList() {
        #expect(CLIParser.parse(["list"]) == .list(pretty: false))
    }

    @Test("--pretty 可出现在任意位置")
    func parsesPretty() {
        #expect(CLIParser.parse(["list", "--pretty"]) == .list(pretty: true))
        #expect(CLIParser.parse(["--pretty", "list"]) == .list(pretty: true))
        #expect(CLIParser.parse(["version", "--pretty"]) == .version(pretty: true))
        #expect(CLIParser.parse(["set-default", "93", "--pretty"]) == .setDefault(id: 93, pretty: true))
    }

    @Test("set-default 需要十进制无符号整数 id")
    func parsesSetDefault() {
        #expect(CLIParser.parse(["set-default", "115"]) == .setDefault(id: 115, pretty: false))
        #expect(CLIParser.parse(["set-default", "abc"]).isUsageError)
        #expect(CLIParser.parse(["set-default", "-1"]).isUsageError)
        #expect(CLIParser.parse(["set-default"]).isUsageError)
    }

    @Test("空参数、未知子命令、未知选项一律是用法错误")
    func rejectsUsage() {
        #expect(CLIParser.parse([]).isUsageError)
        #expect(CLIParser.parse(["bogus"]).isUsageError)
        #expect(CLIParser.parse(["list", "--json"]).isUsageError)
        #expect(CLIParser.parse(["list", "93"]).isUsageError)
    }
}

@Suite("voiceinput-cli 输出契约")
@MainActor
struct CLIRunnerTests {
    private func runner(_ provider: FakeAudioDeviceProvider) -> CLIRunner {
        CLIRunner(provider: provider, appVersion: "1.0.0")
    }

    private func json(_ stdout: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(stdout.utf8))) as? [String: Any] ?? [:]
    }

    @Test("list 输出契约形状，保持 HAL 原序，isDefault 只有一处表达")
    func listShape() {
        let execution = runner(makeStandardProvider()).run(.list(pretty: false))

        #expect(execution.exitCode == 0)
        #expect(execution.stderr.isEmpty)
        let payload = json(execution.stdout)
        #expect(payload["protocol"] as? Int == 1)
        #expect(payload["defaultDeviceID"] == nil)
        let devices = payload["devices"] as? [[String: Any]] ?? []
        #expect(devices.map { $0["id"] as? Int } == [177, 93, 115])
        #expect(devices.map { $0["name"] as? String } == ["vRemoteDr 2ch", "MacBook Pro麦克风", "BlackHole 2ch"])
        #expect(devices.filter { $0["isDefault"] as? Bool == true }.map { $0["id"] as? Int } == [177])
        #expect(Set(devices.flatMap { $0.keys }) == ["id", "name", "displayName", "isDefault"])
    }

    @Test("同名设备在 displayName 上带序号，规则与菜单一致")
    func duplicateNamesGetOrdinals() {
        let provider = FakeAudioDeviceProvider()
        provider.devices = [
            AudioDevice(id: 1, name: "麦克风"),
            AudioDevice(id: 2, name: "麦克风"),
            AudioDevice(id: 3, name: "麦克风"),
        ]
        provider.defaultID = 1

        let devices = json(runner(provider).run(.list(pretty: false)).stdout)["devices"] as? [[String: Any]] ?? []

        #expect(devices.map { $0["displayName"] as? String } == ["麦克风", "麦克风 2", "麦克风 3"])
        #expect(devices.map { $0["name"] as? String } == ["麦克风", "麦克风", "麦克风"])
    }

    @Test("读不到当前默认输入时报 hal_error，而不是给出无勾选的列表")
    func halErrorWhenDefaultUnreadable() {
        let provider = makeStandardProvider()
        provider.defaultID = nil

        let execution = runner(provider).run(.list(pretty: false))

        #expect(execution.exitCode == 3)
        let payload = json(execution.stdout)
        let error = payload["error"] as? [String: Any] ?? [:]
        #expect(payload["protocol"] as? Int == 1)
        #expect(error["code"] as? String == "hal_error")
        #expect((error["message"] as? String)?.isEmpty == false)
        #expect(!execution.stderr.isEmpty)
    }

    @Test("set-default 返回回读后的完整状态，而不是回显入参")
    func setDefaultReturnsReadback() {
        let provider = makeStandardProvider()
        let execution = runner(provider).run(.setDefault(id: 93, pretty: false))

        #expect(execution.exitCode == 0)
        #expect(provider.setDefaultCalls == [93])
        let devices = json(execution.stdout)["devices"] as? [[String: Any]] ?? []
        #expect(devices.filter { $0["isDefault"] as? Bool == true }.map { $0["id"] as? Int } == [93])
    }

    @Test("目标 id 不在设备集合里时是 device_not_found，且不写系统状态")
    func setDefaultUnknownDevice() {
        let provider = makeStandardProvider()
        let execution = runner(provider).run(.setDefault(id: 99999, pretty: false))

        #expect(execution.exitCode == 4)
        #expect(provider.setDefaultCalls.isEmpty)
        let error = json(execution.stdout)["error"] as? [String: Any] ?? [:]
        #expect(error["code"] as? String == "device_not_found")
    }

    @Test("写入失败时是 switch_failed")
    func setDefaultWriteFails() {
        let provider = makeStandardProvider()
        provider.setDefaultStatus = OSStatus(-50)

        let execution = runner(provider).run(.setDefault(id: 93, pretty: false))

        #expect(execution.exitCode == 4)
        let error = json(execution.stdout)["error"] as? [String: Any] ?? [:]
        #expect(error["code"] as? String == "switch_failed")
    }

    @Test("version 输出 protocol 与 appVersion")
    func versionShape() {
        let execution = runner(makeStandardProvider()).run(.version(pretty: false))

        #expect(execution.exitCode == 0)
        let payload = json(execution.stdout)
        #expect(payload["protocol"] as? Int == 1)
        #expect(payload["appVersion"] as? String == "1.0.0")
    }

    @Test("用法错误以 bad_usage + 退出码 2 结束，并给出一行人话")
    func usageError() {
        let execution = runner(makeStandardProvider()).run(.usageError(message: "unknown subcommand", pretty: false))

        #expect(execution.exitCode == 2)
        let error = json(execution.stdout)["error"] as? [String: Any] ?? [:]
        #expect(error["code"] as? String == "bad_usage")
        #expect(!execution.stderr.isEmpty)
    }

    @Test("用法错误也遵守 --pretty")
    func usageErrorHonoursPretty() {
        let execution = runner(makeStandardProvider()).run(.usageError(message: "unknown subcommand", pretty: true))

        #expect(execution.exitCode == 2)
        #expect(execution.stdout.contains("\n  "))
    }

    @Test("枚举不出任何设备时是 hal_error，而不是空列表成功")
    func halErrorWhenNoDevices() {
        let provider = FakeAudioDeviceProvider()
        provider.devices = []
        provider.defaultID = 177

        let execution = runner(provider).run(.list(pretty: false))

        #expect(execution.exitCode == 3)
        let error = json(execution.stdout)["error"] as? [String: Any] ?? [:]
        #expect(error["code"] as? String == "hal_error")
    }

    @Test("默认设备不在设备集合里时是 hal_error，而不是无勾选的列表")
    func halErrorWhenDefaultMissingFromList() {
        let provider = makeStandardProvider()
        provider.defaultID = 42

        let execution = runner(provider).run(.list(pretty: false))

        #expect(execution.exitCode == 3)
        let error = json(execution.stdout)["error"] as? [String: Any] ?? [:]
        #expect(error["code"] as? String == "hal_error")
    }

    @Test("切换后回读失败时是 hal_error，不返回写入前的旧状态")
    func halErrorWhenReadbackFails() {
        let provider = makeStandardProvider()
        provider.defaultID = 177
        provider.clearDefaultAfterWrite = true

        let execution = runner(provider).run(.setDefault(id: 93, pretty: false))

        #expect(execution.exitCode == 3)
        let error = json(execution.stdout)["error"] as? [String: Any] ?? [:]
        #expect(error["code"] as? String == "hal_error")
    }

    @Test("--pretty 只影响排版，语义等价")
    func prettyIsCosmetic() {
        let provider = makeStandardProvider()
        let compact = runner(provider).run(.list(pretty: false))
        let pretty = runner(provider).run(.list(pretty: true))

        #expect(compact.exitCode == 0)
        #expect(pretty.exitCode == 0)
        #expect(pretty.stdout.contains("\n"))
        #expect(json(pretty.stdout) as NSDictionary == json(compact.stdout) as NSDictionary)
    }
}

private extension CLIInvocation {
    var isUsageError: Bool {
        if case .usageError = self { return true }
        return false
    }
}
