import Foundation
import OSLog

/// 单例守卫：用 `flock` 文件锁保证一次最多只有一个 VoiceInput 进程在跑。
///
/// 为什么需要它（而不是只靠系统）：双击 `.app` 时 LaunchServices 确实不会拉起第二个进程，
/// 但 `swift run`、直跑 `Contents/MacOS/VoiceInput` 会绕过 LaunchServices，能起多个实例。
/// 文件锁覆盖所有启动方式——也因此 `swift run` 与已安装的 .app 互斥（两者共用同一把锁）。
///
/// 为什么用 `flock` 而不是「锁文件存在即视为已运行」：锁由内核持有，进程崩溃、被 `kill -9`
/// 时**自动释放**，永远不会留下失效的死锁文件。同理，退出时不能删锁文件——「先删再抢」
/// 会让两个进程各自创建新文件、各拿一把锁，是经典竞态。锁文件自一次创建后长期留着即可。
public final class SingleInstanceGuard {
    /// 是否已有另一个实例在跑。`true` 时本次启动应立即退出。
    public private(set) var anotherInstanceIsRunning: Bool

    /// 锁文件路径。仅用于诊断与测试观察，不承载任何数据。
    public let lockFileURL: URL

    /// 持锁的文件描述符：进程生命周期内必须一直开着，关了锁就没了。
    /// 初值 `-1` 表示没有打开任何文件（未持锁）。
    private var lockFD: Int32 = -1

    /// - Parameter lockFileURL: 锁文件路径；父目录不存在时自动创建。
    public init(lockFileURL: URL) {
        self.lockFileURL = lockFileURL
        self.anotherInstanceIsRunning = false

        // 1. 父目录不存在则创建（首次运行时 Application Support 下还没有本应用的子目录）
        let directory = lockFileURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)
            || !isDirectory.boolValue {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // 2. 打开锁文件（不存在则创建）。0o600：不承载数据，按最小权限建。
        lockFD = open(lockFileURL.path, O_RDWR | O_CREAT, 0o600)
        guard lockFD >= 0 else {
            // 连锁文件都打不开（磁盘满 / 权限异常）：单例保护失效也不能拦住用户用 App，
            // 放行并留下错误日志，让控制台能查到「这次启动没有单例保护」。
            let code = errno
            Self.logger.error(
                "打不开单例锁文件 \(self.lockFileURL.path, privacy: .public)（errno \(code)），本次启动没有单例保护"
            )
            return
        }

        // 3. 非阻塞抢独占锁
        switch Self.tryLock(fd: lockFD) {
        case .acquired:
            return
        case .heldByAnotherProcess:
            close(lockFD)
            lockFD = -1
            anotherInstanceIsRunning = true
            Self.logger.notice(
                "已有实例在运行，本次启动退出（单例锁文件 \(self.lockFileURL.path, privacy: .public)）"
            )
        case .failed(let code):
            close(lockFD)
            lockFD = -1
            // 只有「锁被占用」才说明已有实例；其它失败（如理论上可出现的 EINTR）
            // 不能冤枉成已有实例，与打不开锁文件同样处理：放行，但没有单例保护。
            Self.logger.error(
                "抢单例锁失败 \(self.lockFileURL.path, privacy: .public)（errno \(code)），本次启动没有单例保护"
            )
        }
    }

    deinit {
        // 进程退出时内核也会释放 flock，这里只是尽早归还（测试里紧接着再拿锁要靠它）。
        if lockFD >= 0 {
            close(lockFD)
        }
    }

    /// 默认锁文件位置：`~/Library/Application Support/<bundle id>/instance.lock`。
    ///
    /// 目录名用 bundle id 而非应用名：bundle id 是应用级唯一标识，可避免与同名应用
    /// 抢占同一把锁。改动 `scripts/bundle-app.sh` 的 `BUNDLE_ID` 时这里要同步。
    public static var defaultLockFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent(Self.bundleIdentifier, isDirectory: true)
            .appendingPathComponent("instance.lock")
    }

    private enum LockOutcome {
        case acquired
        case heldByAnotherProcess
        case failed(Int32)
    }

    private static func tryLock(fd: Int32) -> LockOutcome {
        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            return .acquired
        }
        let code = errno
        // Darwin 上 EWOULDBLOCK == EAGAIN：锁正被别的进程持有。
        return code == EWOULDBLOCK ? .heldByAnotherProcess : .failed(code)
    }

    /// 与 `scripts/bundle-app.sh` 的 `BUNDLE_ID` 保持一致：既是 Application Support
    /// 子目录名，也是统一日志的 subsystem。
    private static let bundleIdentifier = "com.fanbingbing.voiceinput"

    private static let logger = Logger(
        subsystem: SingleInstanceGuard.bundleIdentifier,
        category: "SingleInstance"
    )
}
