import Testing
import CoreAudio
@testable import VoiceInputCore

@Suite("MenuModel 菜单渲染")
struct MenuModelTests {
    @Test("按传入顺序渲染设备名，默认设备带勾选前缀")
    func rendersDevicesInGivenOrder() {
        let devices = [
            AudioDevice(id: 41, name: "vRemoteDr 2ch"),
            AudioDevice(id: 17, name: "MacBook Pro 麦克风"),
            AudioDevice(id: 88, name: "BlackHole 2ch"),
        ]

        let items = MenuModel.deviceItems(devices: devices, defaultDeviceID: 17)

        #expect(items.map(\.title) == ["    vRemoteDr 2ch", "✓  MacBook Pro 麦克风", "    BlackHole 2ch"])
    }

    @Test("空设备列表产出空菜单")
    func emptyDevicesProduceNoItems() {
        #expect(MenuModel.deviceItems(devices: [], defaultDeviceID: nil).isEmpty)
    }

    @Test("两个同名设备显示原名与序号后缀")
    func twoDuplicatesGetSuffix() {
        let devices = [
            AudioDevice(id: 1, name: "MacBook 麦克风"),
            AudioDevice(id: 2, name: "MacBook 麦克风"),
        ]

        let items = MenuModel.deviceItems(devices: devices, defaultDeviceID: nil)

        #expect(items.map(\.title) == ["    MacBook 麦克风", "    MacBook 麦克风 2"])
    }

    @Test("三个同名设备依次显示原名、2、3")
    func threeDuplicatesGetSequentialSuffixes() {
        let devices = [
            AudioDevice(id: 1, name: "Mic"),
            AudioDevice(id: 2, name: "Mic"),
            AudioDevice(id: 3, name: "Mic"),
        ]

        let items = MenuModel.deviceItems(devices: devices, defaultDeviceID: nil)

        #expect(items.map(\.title) == ["    Mic", "    Mic 2", "    Mic 3"])
    }

    @Test("同名序号按 HAL 出现次序分配，不按名字排序")
    func suffixFollowsHALOrderNotAlphabetical() {
        let devices = [
            AudioDevice(id: 1, name: "Mic"),
            AudioDevice(id: 2, name: "Mic"),
            AudioDevice(id: 3, name: "Mic"),
        ]

        let items = MenuModel.deviceItems(devices: devices, defaultDeviceID: nil)

        #expect(items.map(\.id) == [1, 2, 3])
        #expect(items.map(\.title) == ["    Mic", "    Mic 2", "    Mic 3"])
    }

    @Test("真实名字自带序号时跳号避让，不与真实名字撞名")
    func realNameWithSuffixIsNotShadowed() {
        let devices = [
            AudioDevice(id: 1, name: "MacBook 麦克风"),
            AudioDevice(id: 2, name: "MacBook 麦克风 2"),
            AudioDevice(id: 3, name: "MacBook 麦克风"),
        ]

        let items = MenuModel.deviceItems(devices: devices, defaultDeviceID: nil)

        #expect(items.map(\.title) == [
            "    MacBook 麦克风",
            "    MacBook 麦克风 2",
            "    MacBook 麦克风 3",
        ])
    }

    @Test("刷新后同名序号稳定不跳变")
    func suffixesAreStableAcrossRefreshes() {
        let devices = [
            AudioDevice(id: 1, name: "Mic"),
            AudioDevice(id: 2, name: "Mic"),
        ]

        let first = MenuModel.deviceItems(devices: devices, defaultDeviceID: nil)
        let second = MenuModel.deviceItems(devices: devices.map { AudioDevice(id: $0.id, name: $0.name) }, defaultDeviceID: nil)

        #expect(first.map(\.title) == second.map(\.title))
    }

    @Test("菜单标题不暴露设备 UID")
    func titlesNeverExposeDeviceID() {
        let devices = [
            AudioDevice(id: 123456, name: "MacBook 麦克风"),
            AudioDevice(id: 789012, name: "MacBook 麦克风"),
        ]

        let items = MenuModel.deviceItems(devices: devices, defaultDeviceID: nil)

        #expect(items.allSatisfy { !$0.title.contains("123456") && !$0.title.contains("789012") })
    }

    @Test("同名设备的勾选前缀与序号并存")
    func defaultPrefixAndSuffixCombine() {
        let devices = [
            AudioDevice(id: 1, name: "Mic"),
            AudioDevice(id: 2, name: "Mic"),
        ]

        let items = MenuModel.deviceItems(devices: devices, defaultDeviceID: 2)

        #expect(items.map(\.title) == ["    Mic", "✓  Mic 2"])
        #expect(items.map(\.isDefault) == [false, true])
    }
}
