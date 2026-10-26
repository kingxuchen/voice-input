import Foundation
import Testing
@testable import VoiceInputCore

/// 单例守卫的行为验证。
///
/// 每个用例用带 UUID 的独立锁路径：Swift Testing 默认并行跑同一 suite 内的用例，
/// 共用路径会互相抢锁；临时目录里的锁文件由系统清理，测试不负责删（删锁文件本身
/// 就是单例实现里明令禁止的竞态操作，测试更不该示范）。
@Suite("单例守卫")
struct SingleInstanceGuardTests {
    private func lockFileURL(_ tag: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceinput-single-instance-\(tag)-\(UUID().uuidString).lock")
    }

    @Test("首个实例拿到锁")
    func firstInstanceAcquiresLock() {
        let guard1 = SingleInstanceGuard(lockFileURL: lockFileURL("first"))

        #expect(guard1.anotherInstanceIsRunning == false)
    }

    @Test("锁被占用时，第二个实例识别出已有实例在跑")
    func secondInstanceDetectsRunningInstance() {
        let url = lockFileURL("second")
        let guard1 = SingleInstanceGuard(lockFileURL: url)
        #expect(guard1.anotherInstanceIsRunning == false)

        let guard2 = SingleInstanceGuard(lockFileURL: url)

        #expect(guard2.anotherInstanceIsRunning == true)
    }

    @Test("实例释放后锁可被再次拿到")
    func lockIsReusableAfterInstanceReleased() {
        let url = lockFileURL("release")

        do {
            let guard1 = SingleInstanceGuard(lockFileURL: url)
            #expect(guard1.anotherInstanceIsRunning == false)
        } // guard1 在此出作用域即释放，锁归还

        let guard2 = SingleInstanceGuard(lockFileURL: url)

        #expect(guard2.anotherInstanceIsRunning == false)
    }

    @Test("锁文件父目录不存在时自动创建，并真的建出锁文件")
    func createsMissingParentDirectory() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceinput-single-instance-dir-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("instance.lock")

        let guard1 = SingleInstanceGuard(lockFileURL: url)

        #expect(guard1.anotherInstanceIsRunning == false)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("锁文件打不开时放行：不能因单例机制拦住用户启动")
    func proceedsWhenLockFileCannotBeOpened() {
        // 让锁文件的父路径是一个普通文件：建目录会失败，open 必然失败
        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceinput-single-instance-blocker-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: blocker.path, contents: Data())
        let url = blocker.appendingPathComponent("instance.lock")

        let guard1 = SingleInstanceGuard(lockFileURL: url)

        #expect(guard1.anotherInstanceIsRunning == false)
    }

    @Test("默认锁文件位于 Application Support 下的 bundle id 目录")
    func defaultLockFileURLTargetsApplicationSupport() {
        let url = SingleInstanceGuard.defaultLockFileURL

        #expect(url.lastPathComponent == "instance.lock")
        #expect(url.deletingLastPathComponent().lastPathComponent == "com.fanbingbing.voiceinput")
        #expect(
            url.deletingLastPathComponent().path.hasPrefix(
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].path
            )
        )
    }
}
