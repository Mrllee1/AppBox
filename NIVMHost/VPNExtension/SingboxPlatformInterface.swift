//
//  SingboxPlatformInterface.swift
//  VPNExtension
//
//  sing-box libbox 的 iOS PlatformInterface 最小实现。
//
//  为什么和 sing-box-for-apple 的 ExtensionPlatformInterface.swift 不同：
//    我们只需要 VLESS + Reality + TUN（无 HTTP proxy / per-app proxy /
//    APN exclude / macOS 特性），所以去掉了所有 macOS / SystemExtension
//    分支 + HTTP proxy 配置 + APN exclude + 系统通知 + Neighbor monitor
//    + WIFI 状态查询 等不相干能力。
//
//  职责：
//    1. openTun(options)：把 libbox 要的 tun 参数翻译成
//       NEPacketTunnelNetworkSettings，调 setTunnelNetworkSettings 激活，
//       然后从 packetFlow 拿 fd 交回 libbox
//    2. 三个 CommandServerHandler 回调：serviceStop / serviceReload /
//       SystemProxyStatus
//    3. writeDebugMessage：sing-box 内部日志 → extLog
//
//  其他一律 stub。

#if !targetEnvironment(simulator)

import Foundation
import Libbox
import NetworkExtension
import Network
import os

final class SingboxPlatformInterface: NSObject,
    LibboxPlatformInterfaceProtocol,
    LibboxCommandServerHandlerProtocol {

    private weak var tunnel: PacketTunnelProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var nwMonitor: NWPathMonitor?

    init(tunnel: PacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func reset() {
        networkSettings = nil
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    // MARK: - LibboxPlatformInterfaceProtocol

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        try runBlocking { [self] in
            try await openTun0(options, ret0_)
        }
    }

    private func openTun0(_ options: LibboxTunOptionsProtocol?,
                          _ ret0_: UnsafeMutablePointer<Int32>?) async throws {
        guard let options, let ret0_ else {
            throw nserr("nil options or return pointer")
        }
        guard let tunnel else {
            throw nserr("tunnel released")
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: options.getMTU())

        let dnsBox = try options.getDNSServerAddress()
        let dns = NEDNSSettings(servers: [dnsBox.value])
        settings.dnsSettings = dns

        var ipv4Address: [String] = []
        var ipv4Mask: [String] = []
        let ipv4Iter = options.getInet4Address()!
        while ipv4Iter.hasNext() {
            let p = ipv4Iter.next()!
            ipv4Address.append(p.address())
            ipv4Mask.append(p.mask())
        }
        let ipv4 = NEIPv4Settings(addresses: ipv4Address, subnetMasks: ipv4Mask)

        var ipv4Routes: [NEIPv4Route] = []
        let v4RouteIter = options.getInet4RouteAddress()!
        if v4RouteIter.hasNext() {
            while v4RouteIter.hasNext() {
                let p = v4RouteIter.next()!
                ipv4Routes.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
            }
        } else {
            ipv4Routes.append(NEIPv4Route.default())
        }
        var ipv4Exclude: [NEIPv4Route] = []
        let v4ExcIter = options.getInet4RouteExcludeAddress()!
        while v4ExcIter.hasNext() {
            let p = v4ExcIter.next()!
            ipv4Exclude.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
        }
        ipv4.includedRoutes = ipv4Routes
        ipv4.excludedRoutes = ipv4Exclude
        settings.ipv4Settings = ipv4

        // IPv6 —— 我们的 SingboxConfigBuilder 默认 enableIPv6=false，但如果
        // 上层传入了 v6 地址也支持
        var ipv6Address: [String] = []
        var ipv6Prefixes: [NSNumber] = []
        let ipv6Iter = options.getInet6Address()!
        while ipv6Iter.hasNext() {
            let p = ipv6Iter.next()!
            ipv6Address.append(p.address())
            ipv6Prefixes.append(NSNumber(value: p.prefix()))
        }
        if !ipv6Address.isEmpty {
            let ipv6 = NEIPv6Settings(addresses: ipv6Address, networkPrefixLengths: ipv6Prefixes)
            var ipv6Routes: [NEIPv6Route] = []
            let v6RouteIter = options.getInet6RouteAddress()!
            if v6RouteIter.hasNext() {
                while v6RouteIter.hasNext() {
                    let p = v6RouteIter.next()!
                    ipv6Routes.append(NEIPv6Route(
                        destinationAddress: p.address(),
                        networkPrefixLength: NSNumber(value: p.prefix())
                    ))
                }
            } else {
                ipv6Routes.append(NEIPv6Route.default())
            }
            var ipv6Exclude: [NEIPv6Route] = []
            let v6ExcIter = options.getInet6RouteExcludeAddress()!
            while v6ExcIter.hasNext() {
                let p = v6ExcIter.next()!
                ipv6Exclude.append(NEIPv6Route(
                    destinationAddress: p.address(),
                    networkPrefixLength: NSNumber(value: p.prefix())
                ))
            }
            ipv6.includedRoutes = ipv6Routes
            ipv6.excludedRoutes = ipv6Exclude
            settings.ipv6Settings = ipv6
        }

        networkSettings = settings
        try await tunnel.setTunnelNetworkSettings(settings)

        // 拿 tun fd：
        //   方式一（sing-box-for-apple 用的）反射 packetFlow.socket.fileDescriptor
        //   方式二 LibboxGetTunnelFileDescriptor()（libbox 里可能做了其他 hack）
        if let fd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32, fd >= 0 {
            ret0_.pointee = fd
            return
        }
        let fallbackFd = LibboxGetTunnelFileDescriptor()
        if fallbackFd != -1 {
            ret0_.pointee = fallbackFd
            return
        }
        throw nserr("missing tun file descriptor")
    }

    func usePlatformAutoDetectControl() -> Bool { false }

    func autoDetectControl(_: Int32) throws {}

    // minimal 构建未启用 process finder，这里抛出即可
    func findConnectionOwner(_: Int32, sourceAddress _: String?, sourcePort _: Int32,
                             destinationAddress _: String?, destinationPort _: Int32) throws -> LibboxConnectionOwner {
        throw nserr("connection owner not supported in minimal build")
    }

    func useProcFS() -> Bool { false }

    // 默认接口监控：sing-box 用于 auto_detect_interface
    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }
        let monitor = NWPathMonitor()
        nwMonitor = monitor
        let sem = DispatchSemaphore(value: 0)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.onPathUpdate(listener, path)
            sem.signal()
            monitor.pathUpdateHandler = { [weak self] path in
                self?.onPathUpdate(listener, path)
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        sem.wait()
    }

    private func onPathUpdate(_ listener: LibboxInterfaceUpdateListenerProtocol, _ path: Network.NWPath) {
        guard path.status != .unsatisfied,
              let iface = path.availableInterfaces.first else {
            listener.updateDefaultInterface("", interfaceIndex: -1, isExpensive: false, isConstrained: false)
            return
        }
        listener.updateDefaultInterface(
            iface.name,
            interfaceIndex: Int32(iface.index),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
        nwMonitor?.cancel()
        nwMonitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let monitor = nwMonitor else {
            return NetworkInterfaceArray([])
        }
        let path = monitor.currentPath
        if path.status == .unsatisfied {
            return NetworkInterfaceArray([])
        }
        var interfaces: [LibboxNetworkInterface] = []
        for it in path.availableInterfaces {
            let lib = LibboxNetworkInterface()
            lib.name = it.name
            lib.index = Int32(it.index)
            switch it.type {
            case .wifi:          lib.type = LibboxInterfaceTypeWIFI
            case .cellular:      lib.type = LibboxInterfaceTypeCellular
            case .wiredEthernet: lib.type = LibboxInterfaceTypeEthernet
            default:             lib.type = LibboxInterfaceTypeOther
            }
            interfaces.append(lib)
        }
        return NetworkInterfaceArray(interfaces)
    }

    func underNetworkExtension() -> Bool { true }

    func includeAllNetworks() -> Bool { false }

    func clearDNSCache() {
        guard let settings = networkSettings, let tunnel = tunnel else { return }
        runBlocking {
            tunnel.reasserting = true
            defer { tunnel.reasserting = false }
            await withCheckedContinuation { c in
                tunnel.setTunnelNetworkSettings(nil) { _ in c.resume() }
            }
            await withCheckedContinuation { c in
                tunnel.setTunnelNetworkSettings(settings) { _ in c.resume() }
            }
        }
    }

    func readWIFIState() -> LibboxWIFIState? { nil }

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? { nil }

    func systemCertificates() -> (any LibboxStringIteratorProtocol)? { nil }

    func send(_: LibboxNotification?) throws {}

    // MARK: - LibboxCommandServerHandlerProtocol

    func serviceStop() throws {
        tunnel?.stopService()
    }

    func serviceReload() throws {
        // minimal：我们不支持运行时 reload（需要停了重启）
        throw nserr("reload not supported in minimal build")
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        status.available = false
        status.enabled = false
        return status
    }

    func setSystemProxyEnabled(_: Bool) throws {}

    func writeDebugMessage(_ message: String?) {
        guard let msg = message, !msg.isEmpty else { return }
        tunnel?.writeMessage("[sing-box] \(msg)")
    }
}

// MARK: - helpers

private func nserr(_ message: String) -> NSError {
    NSError(domain: "SingboxPlatformInterface", code: 0,
            userInfo: [NSLocalizedDescriptionKey: message])
}

/// 同步跑一段 async 代码，仅 Extension 初始化链路上调用（不要在 hot-loop 里用）
func runBlocking(_ block: @escaping () async -> Void) {
    let sem = DispatchSemaphore(value: 0)
    Task.detached {
        await block()
        sem.signal()
    }
    sem.wait()
}

func runBlocking(_ block: @escaping () async throws -> Void) throws {
    var thrown: Error?
    let sem = DispatchSemaphore(value: 0)
    Task.detached {
        do { try await block() } catch { thrown = error }
        sem.signal()
    }
    sem.wait()
    if let e = thrown { throw e }
}

// MARK: - NetworkInterfaceArray

private final class NetworkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    private var current: LibboxNetworkInterface?

    init(_ items: [LibboxNetworkInterface]) {
        self.iterator = items.makeIterator()
    }

    func hasNext() -> Bool {
        current = iterator.next()
        return current != nil
    }

    func next() -> LibboxNetworkInterface? {
        current
    }
}

#endif
