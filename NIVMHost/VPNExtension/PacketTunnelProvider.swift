//
//  PacketTunnelProvider.swift
//  VPNExtension
//
//  sing-box 版 Packet Tunnel（迁移自 Xray+Tun2SocksKit）
//
//  迁移理由：Xray 核心在 Extension 里 RSS 60-65MB，iOS NE 的 50MB Jetsam
//  红线下必 OOM。改用自建 minimal libbox，预计 RSS 35-45MB。
//  详见 pornhub_client/SINGBOX_MINIMAL_PLAN.md
//
//  对接关系：
//    主 App (Runner)           flutter_singbox        本 Extension
//    ────────────────          ───────────────        ─────────────────
//    FlutterVpnService   →  NETunnelProviderProtocol
//                           .providerConfiguration["singboxConfig"]     =  完整 sing-box JSON
//                           .providerConfiguration["oomKillerEnabled"]  =  true
//                           startVPNTunnel()                 ──────────→ startTunnel()
//
//  启动流程：
//    1. 读 providerConfiguration["singboxConfig"] 拿到完整 sing-box JSON
//    2. LibboxSetup(SetupOptions) —— 写 basePath/workingPath/tempPath
//       （用 App Group 容器）+ 开 debug + logMaxLines
//    3. LibboxSetMemoryLimit(true) —— 激活 OOMKillerService（iOS NE 关键！）
//    4. LibboxNewCommandServer(handler, platformInterface)
//    5. server.start() + server.startOrReloadService(config, OverrideOptions)
//       → libbox 内部回调 platformInterface.openTun()，我们把 tun fd 返给它
//    6. 保持运行直到 stopTunnel
//

import Foundation
import NetworkExtension

#if targetEnvironment(simulator)

/// iOS Simulator stub.
///
/// 真机包必须使用真实 Libbox + NetworkExtension；模拟器仅用于页面/业务调试，
/// 没有必要也不应该依赖 Libbox.xcframework。配合
/// `FLUTTER_SINGBOX_SIMULATOR_STUB=1` 时，主 App 的 flutter_singbox 插件也会
/// 走 no-op stub。
class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data,
                                   completionHandler: ((Data?) -> Void)?) {
        completionHandler?("simulator-stub".data(using: .utf8))
    }
}

#else

import Libbox
import os
import Darwin

// MARK: - 运行期日志 & 跨进程 IPC key

fileprivate let osLog = Logger(subsystem: "SingboxTunnel", category: "tunnel")

/// App Group —— 仅作为跨进程实时流量 IPC 用途（不再写调试环形日志）。
/// 必须与 Runner/VPNExtension entitlements + flutter_singbox iOS 插件的
/// 同名常量保持一致。
fileprivate let kAppGroup = "group.app.nqyqstm6mu.tianya"

/// ⚠️ 跨进程（主 App ↔ VPN Extension）实时流量通道的 App Group UserDefaults key。
/// Extension 里 [LibboxCommandClient] 每秒回调一次 writeStatus，写入 `[String: Any]`：
///   { "uplink":        <当前秒上行 B/s>,
///     "downlink":      <当前秒下行 B/s>,
///     "uplinkTotal":   <累计上行 B>,
///     "downlinkTotal": <累计下行 B>,
///     "ts":            <写入时间戳 ms> }
/// 主 App 轮询此 key，通过 traffic EventChannel 推给 Dart 显示。
fileprivate let kTrafficStatsKey = "vpnTrafficStats"

/// ⚠️ 跨进程（主 App ↔ VPN Extension）实时延迟采样通道的 App Group UserDefaults key。
/// Extension 里每 5s 调一次 `LibboxCommandServer.urlTestOutbound(...)`，写入：
///   { "latencyMs": <int>,     // -1 表示探测失败/超时
///     "ts":        <写入时间戳 ms> }
fileprivate let kLatencyStatsKey = "vpnLatencyStats"

/// 轻量日志：走 os.Logger(.public) + NSLog + App Group 文件 (`ext.log`)。
///
/// iOS Privacy Hardening 下 App Store 包的 NSLog 会被抹成 `<private>`，且
/// os.Logger 的内容普通用户读不到；因此必须再落地一份文件到 App Group 容器，
/// 这样主 App 里的 `VpnLogsPage` 能通过 `FlutterSingbox.readNativeLog()`
/// 回读 Extension 崩溃/报错现场，供线上排障。
///
/// 文件：`{AppGroup容器}/singbox/ext.log`
///
/// ⚠️ **关键实现决策：同步写**
///
/// 早期版本走 `DispatchQueue.async` 异步落盘，结果线上遇到"Extension 启动
/// 200ms 内崩溃"的问题——崩溃前只有第一条日志入队执行，后续全部丢失。
/// 这让排障完全失去了 ext.log 的价值（恰恰是最关键的崩溃点看不到）。
///
/// 现改用单实例 FileHandle + 串行 DispatchQueue 同步写：
/// - 每次 extLog 入口 `extLogLock` 互斥；
/// - 直接 `handle.write(contentsOf:)` 落盘；
/// - sing-box core 的重负载日志走 core.log（libbox 自身写），ext.log 只记
///   Extension 级生命周期事件，每秒也就几条，同步写性能完全 OK。
fileprivate let kExtLogMaxBytes: UInt64 = 512 * 1024
fileprivate let kExtLogKeepBytes: Int = 256 * 1024
fileprivate let extLogLock = NSLock()

/// 返回 Extension 日志文件 URL；容器不可用时返回 nil。
/// 不抛异常——容器准备失败时静默退化为"只打 os.Logger/NSLog"。
fileprivate func extLogFileURL() -> URL? {
    guard let root = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kAppGroup)
    else { return nil }
    let dir = root.appendingPathComponent("singbox", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
        do {
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
    }
    return dir.appendingPathComponent("ext.log", isDirectory: false)
}

/// core 日志 URL（sing-box log.output 指向的位置），供主 App 读取。
fileprivate func coreLogFileURL() -> URL? {
    guard let root = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kAppGroup)
    else { return nil }
    return root.appendingPathComponent("singbox", isDirectory: true)
        .appendingPathComponent("core.log", isDirectory: false)
}

/// 同步追加一条日志到 ext.log。调用方已持 [extLogLock]。
fileprivate func appendExtLogFileUnsafe(_ line: String) {
    guard let url = extLogFileURL() else { return }
    guard let data = line.data(using: .utf8) else { return }
    let fm = FileManager.default
    if !fm.fileExists(atPath: url.path) {
        fm.createFile(atPath: url.path, contents: nil)
    }
    // 每次都新开 handle → 写入 → 关闭，确保 flush。频率低（秒级几条），
    // 开销可忽略；避免跨调用持有 handle 带来的状态管理复杂度。
    guard let handle = try? FileHandle(forWritingTo: url) else { return }
    do {
        let size = try handle.seekToEnd()
        // 超过上限就截断：读末尾 keep，truncate，写回
        if size > kExtLogMaxBytes {
            let start = max(0, Int(size) - kExtLogKeepBytes)
            try handle.seek(toOffset: UInt64(start))
            let keep = try handle.readToEnd() ?? Data()
            try handle.truncate(atOffset: 0)
            if let head = "…(log truncated to last \(keep.count)B)\n"
                .data(using: .utf8) {
                try handle.write(contentsOf: head)
            }
            try handle.write(contentsOf: keep)
        }
        try handle.write(contentsOf: data)
    } catch {
        // 静默失败，不影响 VPN 启动
    }
    try? handle.close()
}

fileprivate func extLog(_ msg: String, isError: Bool = false) {
    if isError {
        osLog.error("\(msg, privacy: .public)")
    } else {
        osLog.notice("\(msg, privacy: .public)")
    }
    NSLog("[SingboxTunnel] \(msg)")

    let ts = ISO8601DateFormatter().string(from: Date())
    let lvl = isError ? "ERR " : "INFO"
    let line = "[\(ts)] [\(lvl)] \(msg)\n"
    extLogLock.lock()
    appendExtLogFileUnsafe(line)
    extLogLock.unlock()
}

// MARK: - PacketTunnelProvider

/// 注意：这个类名 `PacketTunnelProvider` **必须保持**，Info.plist 里
/// `NSExtensionPrincipalClass=$(PRODUCT_MODULE_NAME).PacketTunnelProvider`
/// 硬编码了这个名字，改了会让 iOS 找不到入口。
class PacketTunnelProvider: NEPacketTunnelProvider {

    private var commandServer: LibboxCommandServer?
    private var commandClient: LibboxCommandClient?
    private var commandClientHandler: TrafficCommandClientHandler?
    private var platformInterface: SingboxPlatformInterface?
    private var memoryProbeTimer: DispatchSourceTimer?
    private var latencyProbeTimer: DispatchSourceTimer?

    override func startTunnel(options: [String : NSObject]? = nil) async throws {
        // 进入启动流程就立刻打一条「现场锚点」，配合 extLog 同步落盘，
        // 即使后续任何异常崩溃都能在 ext.log 里看到时间点。
        extLog("==== startTunnel entered @ \(ISO8601DateFormatter().string(from: Date())) ====")
        extLog("iOS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
        do {
            try await startTunnelImpl(options: options)
        } catch {
            // 关键：保证 Swift 任何 throw / Go Runtime 崩溃前的最后状态能看到
            let detail = "startTunnel FAILED: \(type(of: error)) \(error.localizedDescription)"
            extLog(detail, isError: true)
            // NSError 的 userInfo/domain/code 通常携带关键信息
            if let ns = error as NSError? {
                extLog("  domain=\(ns.domain) code=\(ns.code) userInfo=\(ns.userInfo)",
                       isError: true)
            }
            throw error
        }
    }

    private func startTunnelImpl(options: [String : NSObject]? = nil) async throws {
        guard
            let proto = protocolConfiguration as? NETunnelProviderProtocol,
            let providerConfiguration = proto.providerConfiguration
        else {
            throw nserr("providerConfiguration 缺失")
        }

        let configString: String = try {
            if let s = providerConfiguration["singboxConfig"] as? String, !s.isEmpty {
                return s
            }
            if let d = providerConfiguration["singboxConfig"] as? Data,
               let s = String(data: d, encoding: .utf8), !s.isEmpty {
                return s
            }
            throw nserr("singboxConfig 缺失（需要完整的 sing-box JSON String）")
        }()

        extLog("step: config loaded, size=\(configString.count) chars")
        extLog("core=sing-box minimal, version=\(LibboxVersion())")

        // ---------------- libbox 基础 setup ----------------
        let dirs = try prepareWorkingDirectories()
        extLog("step: prepareWorkingDirectories ok (base=\(dirs.base.path))")
        // core.log 无限 append 前先回滚一次，避免占满 App Group 配额。
        // 失败必须静默，不能阻止 VPN 启动。
        rollCoreLogIfTooBig()
        extLog("step: rollCoreLogIfTooBig done")
        let setupOptions = LibboxSetupOptions()
        setupOptions.basePath = dirs.base.path
        setupOptions.workingPath = dirs.working.path
        setupOptions.tempPath = dirs.temp.path
        // iOS NE 50MB jetsam 红线下，libbox 日志环形缓冲也是内存开销之一。
        // 3000 行 ≈ 1MB RSS，降到 1000 行能腾出 ~700KB；ext.log 里 Extension
        // 生命周期关键事件由我们自己 extLog() 同步落盘到 App Group，core 日志
        // 也落 core.log 磁盘，线上排障窗口完全够用。
        setupOptions.logMaxLines = 1000
        setupOptions.debug = false
        // ⚠️ 关键：iOS NE 下 App Group 容器路径接近 sockaddr_un.sun_path 上限
        // (104 bytes)，会导致 CommandServer 默认的 unix socket bind 失败 —
        // `listen unix ...command.sock: bind: invalid argument`。
        // 设置 `commandServerListenPort` 后 libbox 改走 TCP localhost:<port>，
        // 彻底绕开 sun_path 限制。端口仅在本 extension 内环回，不暴露到网络。
        setupOptions.commandServerListenPort = 0xCBBC  // 任选一个不常用端口 (52156)
        var setupError: NSError?
        LibboxSetup(setupOptions, &setupError)
        if let e = setupError {
            throw nserr("LibboxSetup 失败: \(e.localizedDescription)")
        }

        // ⚠️ 关键：开 memory limit → 激活 OOMKillerService + gc pressure hints。
        // 对 iOS NE 的 50MB Jetsam 红线至关重要。
        LibboxSetMemoryLimit(true)
        extLog("LibboxSetup ok (basePath=\(dirs.base.path)), memoryLimit=on, cmdPort=\(setupOptions.commandServerListenPort)")

        // ---------------- CommandServer + PlatformInterface ----------------
        extLog("step: create PlatformInterface")
        let pi = SingboxPlatformInterface(tunnel: self)
        platformInterface = pi

        extLog("step: LibboxNewCommandServer")
        var serverError: NSError?
        guard let server = LibboxNewCommandServer(pi, pi, &serverError) else {
            throw nserr("LibboxNewCommandServer 失败: \(serverError?.localizedDescription ?? "unknown")")
        }
        commandServer = server
        extLog("step: LibboxNewCommandServer ok")

        do {
            extLog("step: commandServer.start (TCP 127.0.0.1:\(setupOptions.commandServerListenPort))")
            try server.start()
            extLog("step: commandServer.start ok")
        } catch {
            throw nserr("commandServer.start 失败: \(error.localizedDescription)")
        }

        // ---------------- 启动 sing-box Service ----------------
        // 注入 core 日志落盘到 App Group 容器，主 App 能通过 readNativeLog 读回。
        let finalConfig = injectCoreLogOutput(into: configString)
        extLog("step: config inject done, finalSize=\(finalConfig.count) chars")
        // 把配置头 400 字节打印出来，用于排查注入是否生效 + 关键参数（stack/mtu 等）
        let preview = String(finalConfig.prefix(400))
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        extLog("configPreview: \(preview)…")
        extLog("step: startOrReloadService begin")
        let override = LibboxOverrideOptions()
        do {
            try server.startOrReloadService(finalConfig, options: override)
            extLog("step: startOrReloadService ok")
        } catch {
            // 启动失败要清理 commandServer，否则下次 startTunnel 会重复注册
            server.close()
            commandServer = nil
            platformInterface = nil
            throw nserr("startOrReloadService 失败: \(error.localizedDescription)")
        }

        extLog("sing-box Service 启动成功，等待业务流量...")

        // ---------------- 订阅实时流量 ----------------
        startTrafficSubscription()

        // ---------------- 真实延迟采样（5s 一次）----------------
        startLatencyProbeTimer()

        // ---------------- 内存监控 ----------------
        startMemoryProbeTimer()
        Self.logMemorySample(Self.currentResidentMemoryMB(), force: true)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        extLog("stopTunnel reason=\(reason.rawValue)")
        memoryProbeTimer?.cancel()
        memoryProbeTimer = nil
        latencyProbeTimer?.cancel()
        latencyProbeTimer = nil

        stopTrafficSubscription()
        stopLatencyProbe()

        stopService()
        if let server = commandServer {
            // 给 go routine 100ms 收尾时间，然后再 close（参考 sing-box-for-apple）
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
                server.close()
                self?.commandServer = nil
                self?.platformInterface = nil
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }

    /// 由 PlatformInterface.serviceStop 回调进来（sing-box core 主动停）
    func stopService() {
        if let server = commandServer {
            do {
                try server.closeService()
            } catch {
                extLog("closeService 失败: \(error.localizedDescription)", isError: true)
            }
        }
        platformInterface?.reset()
    }

    /// sing-box core 内部日志 → App Group 日志
    func writeMessage(_ message: String) {
        extLog(message)
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(messageData)
            return
        }
        switch message {
        case "version":
            completionHandler?(LibboxVersion().data(using: .utf8))
        default:
            completionHandler?(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        if let server = commandServer {
            server.pause()
        }
        completionHandler()
    }

    override func wake() {
        if let server = commandServer {
            server.wake()
        }
    }

    // MARK: - 实时流量订阅

    /// 启动 [LibboxCommandClient] 订阅 sing-box core 的 CommandStatus 流。
    ///
    /// core 里启用了 `with_clash_api` + `experimental.clash_api` 配置块，
    /// 内部维护全局上/下行字节计数器。CommandClient 每秒通过 gRPC
    /// (127.0.0.1:0xCBBC) 拉取一次 LibboxStatusMessage，把最新 uplink/downlink
    /// 写到 App Group UserDefaults，供主 App 轮询读取 → UI 显示。
    ///
    /// dial target 由 libbox 内部根据 `sCommandServerListenPort` 决定：
    /// Extension 里 setupOptions.commandServerListenPort = 0xCBBC，所以走 TCP
    /// loopback（绕开 App Group 容器路径 ≥ sun_path 上限 104 bytes 的问题）。
    ///
    /// Connect() 会阻塞重试 ≤ ~1.5s，所以放到独立 DispatchQueue。
    private func startTrafficSubscription() {
        let handler = TrafficCommandClientHandler()
        commandClientHandler = handler

        let options = LibboxCommandClientOptions()
        options.statusInterval = 1_000_000_000 // 1s（ns）
        options.addCommand(LibboxCommandStatus)

        guard let client = LibboxNewCommandClient(handler, options) else {
            extLog("LibboxNewCommandClient failed", isError: true)
            return
        }
        commandClient = client

        DispatchQueue.global(qos: .utility).async { [weak client] in
            do {
                try client?.connect()
            } catch {
                extLog("command client connect failed: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func stopTrafficSubscription() {
        if let client = commandClient {
            do { try client.disconnect() } catch { /* ignore */ }
        }
        commandClient = nil
        commandClientHandler = nil
        // 断开后清一下共享 UD，避免主 App 读到"卡死速率"
        if let ud = UserDefaults(suiteName: kAppGroup) {
            ud.removeObject(forKey: kTrafficStatsKey)
        }
    }

    // MARK: - 真实延迟采样

    /// 每 5s 对 sing-box default outbound 做一次 HTTP HEAD 延迟探测（走真实代理链路）。
    ///
    /// 实现：直接调我们在 libbox 里新增的 `LibboxCommandServer.urlTestOutbound`
    /// 导出方法，内部用 sing-box 内置 urltest.URLTest，TCP+TLS+HTTP 端到端耗时。
    ///
    /// 结果写入 App Group UserDefaults[`kLatencyStatsKey`]，主 App 的
    /// TrafficStreamHandler 轮询时顺便读出，塞进 TrafficEvent 送给 Dart。
    ///
    /// latencyMs == -1 表示探测失败/超时。
    private func startLatencyProbeTimer() {
        latencyProbeTimer?.cancel()
        let q = DispatchQueue(label: "vpn.latency.probe", qos: .utility)
        let t = DispatchSource.makeTimerSource(queue: q)
        t.schedule(deadline: .now() + 2.0, repeating: 5.0, leeway: .seconds(1))
        t.setEventHandler { [weak self] in
            self?.probeLatencyOnce()
        }
        t.resume()
        latencyProbeTimer = t
    }

    private func probeLatencyOnce() {
        guard let server = commandServer else { return }
        var latencyMs: Int32 = -1
        var ok = false
        do {
            var ret: Int32 = 0
            try server.urlTestOutbound(
                "",
                link: "https://www.gstatic.com/generate_204",
                timeoutMs: 3000,
                ret0_: &ret
            )
            latencyMs = ret
            ok = ret >= 0
        } catch {
            latencyMs = -1
            ok = false
        }
        guard let ud = UserDefaults(suiteName: kAppGroup) else { return }
        let payload: [String: Any] = [
            "latencyMs": Int(latencyMs),
            "ok": ok,
            "ts": Int64(Date().timeIntervalSince1970 * 1000),
        ]
        ud.set(payload, forKey: kLatencyStatsKey)
    }

    private func stopLatencyProbe() {
        if let ud = UserDefaults(suiteName: kAppGroup) {
            ud.removeObject(forKey: kLatencyStatsKey)
        }
    }

    // MARK: - 内存监控

    /// ⚠️ 用 DispatchSourceTimer 而非 Foundation.Timer：
    /// NE 是 headless 进程，RunLoop.main 不跑，Foundation.Timer 不触发。
    /// DispatchSourceTimer 由 libdispatch 内核线程驱动，不受 runloop 影响。
    private func startMemoryProbeTimer() {
        memoryProbeTimer?.cancel()
        let q = DispatchQueue(label: "vpn.memory.probe", qos: .utility)
        let t = DispatchSource.makeTimerSource(queue: q)
        t.schedule(deadline: .now() + 5.0, repeating: 5.0, leeway: .seconds(1))
        t.setEventHandler {
            let mb = Self.currentResidentMemoryMB()
            Self.logMemorySample(mb, force: false)
        }
        t.resume()
        memoryProbeTimer = t
    }

    private static var lastMemoryMB: Double = 0
    private static func logMemorySample(_ mb: Double, force: Bool) {
        let diff = abs(mb - lastMemoryMB)
        let warn = mb >= 35.0
        if !force && diff < 0.5 && !warn { return }
        lastMemoryMB = mb
        extLog(
            String(format: "📊 Extension 内存 = %.1f MB%@", mb,
                   warn ? "  ⚠️ 接近 50MB 上限" : ""),
            isError: mb >= 45.0
        )
    }

    /// 读取当前 Extension 进程的常驻物理内存（MB）。
    /// 使用 Mach task_info + MACH_TASK_BASIC_INFO，和 Xcode Debug Navigator 同口径。
    private static func currentResidentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1024.0 / 1024.0
    }

    // MARK: - helpers

    /// 在 App Group 容器里准备 sing-box 的工作目录：
    ///   base/       —— 写配置快照、日志（libbox 会 mkdir 自己需要的子目录）
    ///   working/    —— sing-box 运行期写入
    ///   temp/       —— 短生命周期缓存
    private struct Dirs {
        let base: URL
        let working: URL
        let temp: URL
    }

    private func prepareWorkingDirectories() throws -> Dirs {
        let fm = FileManager.default
        guard let root = fm.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            throw nserr("App Group 容器 \(kAppGroup) 不可用（检查 entitlements）")
        }
        let base = root.appendingPathComponent("singbox", isDirectory: true)
        let working = base.appendingPathComponent("working", isDirectory: true)
        let temp = base.appendingPathComponent("temp", isDirectory: true)
        for d in [base, working, temp] {
            if !fm.fileExists(atPath: d.path) {
                try fm.createDirectory(at: d, withIntermediateDirectories: true)
            }
        }
        return Dirs(base: base, working: working, temp: temp)
    }
}

// MARK: - TrafficCommandClientHandler

/// [LibboxCommandClientHandler] 实现：只关心 writeStatus 回调，
/// 其余（logs/groups/clash mode/connection events）全部空实现。
///
/// 写入路径：writeStatus → App Group UserDefaults[kTrafficStatsKey]
/// 主 App 侧的 FlutterSingboxPlugin（主进程）会以 1s 周期轮询读出，
/// 通过新的 traffic EventChannel 推给 Dart。
fileprivate class TrafficCommandClientHandler: NSObject, LibboxCommandClientHandlerProtocol {

    private lazy var sharedUD: UserDefaults? = UserDefaults(suiteName: kAppGroup)

    func connected() {}
    func disconnected(_ message: String?) {}
    func clearLogs() {}
    func setDefaultLogLevel(_ level: Int32) {}
    func writeLogs(_ messageList: LibboxLogIteratorProtocol?) {}
    func writeGroups(_ message: LibboxOutboundGroupIteratorProtocol?) {}
    func initializeClashMode(_ modeList: LibboxStringIteratorProtocol?, currentMode: String?) {}
    func updateClashMode(_ newMode: String?) {}
    // Swift 的 ObjC 互操作会把 `writeConnectionEvents:(LibboxConnectionEvents*)`
    // 自动裁剪为 `write(_:)`（因为方法尾词与参数类型重复）。
    // 这里必须使用裁剪后的名字才能正确实现协议，否则编译报错：
    // 'writeConnectionEvents' has been renamed to 'write(_:)'
    func write(_ events: LibboxConnectionEvents?) {}

    func writeStatus(_ message: LibboxStatusMessage?) {
        guard let m = message, let ud = sharedUD else { return }
        let payload: [String: Any] = [
            "uplink": m.uplink,
            "downlink": m.downlink,
            "uplinkTotal": m.uplinkTotal,
            "downlinkTotal": m.downlinkTotal,
            "ts": Int64(Date().timeIntervalSince1970 * 1000),
        ]
        ud.set(payload, forKey: kTrafficStatsKey)
        // 不调 synchronize —— 1Hz 频率若每次同步会显著放大磁盘 IO，
        // 系统会在几秒内自动刷盘，主 App 的读延迟完全可接受。
    }
}

// MARK: - helpers

fileprivate func nserr(_ msg: String, code: Int = 1) -> NSError {
    extLog(msg, isError: true)
    return NSError(domain: "SingboxTunnel", code: code,
                   userInfo: [NSLocalizedDescriptionKey: msg])
}

/// core.log 文件大小上限 + 启动时保留末尾大小（越小越节省 App Group 容量，
/// 越大线上能回看的现场越多）。
fileprivate let kCoreLogMaxBytes: UInt64 = 2 * 1024 * 1024
fileprivate let kCoreLogKeepBytes: Int = 512 * 1024

/// 若 core.log 大于 [kCoreLogMaxBytes]，裁剪为末尾 [kCoreLogKeepBytes]。
/// 每次 startTunnel 前调用一次即可。
fileprivate func rollCoreLogIfTooBig() {
    guard let url = coreLogFileURL() else { return }
    let fm = FileManager.default
    guard fm.fileExists(atPath: url.path) else { return }
    do {
        let attrs = try fm.attributesOfItem(atPath: url.path)
        guard let size = attrs[.size] as? UInt64 else { return }
        if size <= kCoreLogMaxBytes { return }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let start = Int(size) - kCoreLogKeepBytes
        try handle.seek(toOffset: UInt64(max(start, 0)))
        let keep = try handle.readToEnd() ?? Data()
        try handle.truncate(atOffset: 0)
        if let header = "…(core.log rolled, kept last \(keep.count)B)\n"
            .data(using: .utf8) {
            try handle.write(contentsOf: header)
        }
        try handle.write(contentsOf: keep)
    } catch {
        // ignore，不影响 VPN 启动
    }
}

/// 把 sing-box 配置里的 `log.output` 指到 App Group 容器的 `core.log`，
/// 这样 core 里 DNS / outbound / route / tun 的报错都能落盘，主 App
/// 通过 `FlutterSingbox.readNativeLog()` 回读给 [VpnLogsPage] 展示。
///
/// 防护层（任何一环失败都回退为"原样配置"，绝不阻止 VPN 启动）：
///  1. 若 App Group 容器不可用 → 原样返回
///  2. 若预创建 core.log 文件失败（沙盒/权限/磁盘满）→ 原样返回
///  3. 若 JSON 格式异常 → 原样返回
fileprivate func injectCoreLogOutput(into config: String) -> String {
    guard let url = coreLogFileURL() else {
        extLog("injectCoreLogOutput: coreLogFileURL unavailable, skip")
        return config
    }
    // 预 touch：确保 libbox / sing-box core 能打开该文件；失败就绕开。
    let fm = FileManager.default
    if !fm.fileExists(atPath: url.path) {
        if !fm.createFile(atPath: url.path, contents: nil) {
            extLog("injectCoreLogOutput: cannot create core.log at \(url.path), skip",
                   isError: true)
            return config
        }
    }
    guard fm.isWritableFile(atPath: url.path) else {
        extLog("injectCoreLogOutput: core.log not writable, skip", isError: true)
        return config
    }
    guard let data = config.data(using: .utf8) else { return config }
    do {
        guard var root = try JSONSerialization
            .jsonObject(with: data) as? [String: Any]
        else { return config }
        var log = (root["log"] as? [String: Any]) ?? [:]
        // 用户已手动指定 output 时就不覆盖（向后兼容）
        if (log["output"] as? String)?.isEmpty == false {
            return config
        }
        log["output"] = url.path
        // 级别保底 info（sing-box 支持：trace/debug/info/warn/error/fatal/panic）
        if log["level"] == nil { log["level"] = "info" }
        if log["timestamp"] == nil { log["timestamp"] = true }
        root["log"] = log
        let out = try JSONSerialization
            .data(withJSONObject: root, options: [])
        return String(data: out, encoding: .utf8) ?? config
    } catch {
        extLog("injectCoreLogOutput: JSON failed \(error.localizedDescription)",
               isError: true)
        return config
    }
}

#endif
