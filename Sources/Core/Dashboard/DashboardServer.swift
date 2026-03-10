import Foundation

/// Listens on a Unix domain socket for events from Ghostty shell integration.
/// Similar to HookServer but handles DashboardEvent protocol.
public final class DashboardServer {
    private var listenFD: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.cosmodrome.dashboard", qos: .utility)
    private(set) public var socketPath: String?

    public var onEvent: ((DashboardEvent) -> Void)?
    /// Also handle raw HookEvents (Claude Code lifecycle)
    public var onHookEvent: ((HookEvent) -> Void)?

    public init() {}

    deinit { stop() }

    /// Start listening. Returns the socket path.
    @discardableResult
    public func start() -> String {
        let path = NSTemporaryDirectory() + "cosmodrome-dashboard-\(ProcessInfo.processInfo.processIdentifier).sock"
        start(socketPath: path)
        return path
    }

    public func start(socketPath path: String) {
        stop()
        socketPath = path
        unlink(path)

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            close(listenFD); listenFD = -1; return
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dst in
                pathBytes.withUnsafeBufferPointer { src in
                    _ = memcpy(dst, src.baseAddress!, src.count)
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(listenFD, sockaddrPtr, addrLen)
            }
        }
        guard bindResult == 0 else { close(listenFD); listenFD = -1; return }
        guard listen(listenFD, 10) == 0 else { close(listenFD); listenFD = -1; return }

        let source = DispatchSource.makeReadSource(fileDescriptor: listenFD, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptConnection() }
        source.setCancelHandler { [weak self] in
            if let fd = self?.listenFD, fd >= 0 { close(fd); self?.listenFD = -1 }
        }
        source.resume()
        listenSource = source
    }

    public func stop() {
        listenSource?.cancel()
        listenSource = nil
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
        if let path = socketPath { unlink(path); socketPath = nil }
    }

    private func acceptConnection() {
        let clientFD = accept(listenFD, nil, nil)
        guard clientFD >= 0 else { return }

        var data = Data()
        let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }

        while true {
            let n = read(clientFD, buf, bufSize)
            if n > 0 { data.append(buf, count: n) } else { break }
        }
        close(clientFD)
        guard !data.isEmpty else { return }

        // Try parsing as a DashboardEvent first, then as a HookEvent
        if let event = DashboardEvent.parse(from: data) {
            onEvent?(event)
        } else if let hookEvent = HookEvent.parse(from: data) {
            onHookEvent?(hookEvent)
        }
    }
}
